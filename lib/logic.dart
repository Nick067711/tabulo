import 'dart:math';

import 'state.dart';

final Random _r = Random();

int rnd(int a, int b) => b <= a ? a : a + _r.nextInt(b - a + 1);

/// Key used to spot repeated tasks. With [ordered] false, 23 + 7 and 7 + 23
/// count as the same task (only for + and ×, where order does not matter).
String taskKey(Task t, {bool ordered = false}) {
  if (!ordered && (t.op == Op.add || t.op == Op.mul)) {
    final lo = t.a < t.b ? t.a : t.b;
    final hi = t.a < t.b ? t.b : t.a;
    return '${t.op.name}$lo-$hi';
  }
  return '${t.op.name}${t.a}-${t.b}';
}

/// Picks tasks without repeats. First every task is new; when the pool runs out,
/// a swapped order (7 + 23 after 23 + 7) is allowed; only after that may a task
/// come back, and never twice in a row.
class NoRepeat {
  final Set<String> _plain = {};
  final Set<String> _ordered = {};
  Task? _prev;

  Task pick(Task Function() make) {
    for (var stage = 0; stage < 3; stage++) {
      for (var i = 0; i < 400; i++) {
        final t = make();
        if (_prev != null && _prev!.same(t)) continue;
        if (stage == 0 && _plain.contains(taskKey(t))) continue;
        if (stage == 1 && _ordered.contains(taskKey(t, ordered: true))) continue;
        return _take(t);
      }
    }
    return _take(make());
  }

  Task _take(Task t) {
    _plain.add(taskKey(t));
    _ordered.add(taskKey(t, ordered: true));
    _prev = t;
    return t;
  }
}

/// Generates tasks for the exercise modules, following the module settings.
class Gen {
  static List<Task> exercise(Op op, ModuleConfig c, int count) {
    final picker = NoRepeat();
    return [for (var i = 0; i < count; i++) picker.pick(() => _one(op, c))];
  }

  /// Too obvious for practice: adding or subtracting 0, 1 or 10.
  static bool _easy(int n) => n == 0 || n == 1 || n == 10;

  static Task _one(Op op, ModuleConfig c) {
    final missing = _r.nextInt(100) < 35;
    final nums = c.numbers.isEmpty ? [2, 3, 4, 5, 6, 7, 8, 9] : c.numbers;
    if (op == Op.mul) {
      final x = nums[_r.nextInt(nums.length)];
      final y = rnd(1, 10);
      return _r.nextBool() ? Task(Op.mul, x, y, missing: missing) : Task(Op.mul, y, x, missing: missing);
    }
    if (op == Op.div) {
      final d = nums[_r.nextInt(nums.length)];
      final q = rnd(1, 10);
      if (d == 0) return Task(Op.div, q, 1, missing: missing);
      return Task(Op.div, d * q, d, missing: missing);
    }
    final max = AppState.ranges[c.range.clamp(0, 3)];
    if (op == Op.add) {
      for (var i = 0; i < 300; i++) {
        final a = rnd(2, max - 2);
        final b = rnd(2, max - a);
        if (_easy(a) || _easy(b)) continue;
        if (!c.carry && max > 10 && (a % 10) + (b % 10) >= 10) continue;
        return Task(Op.add, a, b, missing: missing);
      }
      return Task(Op.add, 3, 4, missing: missing);
    }
    for (var i = 0; i < 300; i++) {
      final a = rnd(4, max);
      final b = rnd(2, a - 2);
      if (_easy(b)) continue;
      if (!c.carry && max > 10 && (a % 10) < (b % 10)) continue;
      return Task(Op.sub, a, b, missing: missing);
    }
    return Task(Op.sub, 7, 3, missing: missing);
  }

  /// Quiz tasks. Group 0: + and − up to 100, never adding or subtracting 0, 1 or 10.
  /// Group 1: × and ÷ with factors 2–9 (no ×0, ×1, ×10, no n : n).
  /// [picker] keeps the quiz free of repeats.
  static Task quiz(int group, NoRepeat picker) => picker.pick(() => _quizOne(group));

  static bool _ok(int n) => n != 0 && n != 1 && n != 10;

  static Task _quizOne(int group) {
    if (group == 0) {
      if (_r.nextBool()) {
        for (var i = 0; i < 200; i++) {
          final a = rnd(2, 90);
          final b = rnd(2, 100 - a);
          if (_ok(a) && _ok(b)) return Task(Op.add, a, b);
        }
        return const Task(Op.add, 23, 45);
      }
      for (var i = 0; i < 200; i++) {
        final a = rnd(20, 100);
        final b = rnd(2, a - 1);
        if (_ok(b)) return Task(Op.sub, a, b);
      }
      return const Task(Op.sub, 57, 23);
    }
    final a = rnd(2, 9);
    final b = rnd(2, 9);
    if (_r.nextBool()) return Task(Op.mul, a, b);
    return Task(Op.div, a * b, a);
  }

  /// Four answer options, one of them correct, the others close to it.
  static List<int> options(Task t) {
    final ans = t.answer;
    final cand = <int>[];
    if (t.op == Op.mul && !t.missing) {
      cand.addAll([t.a * (t.b + 1), t.a * (t.b - 1), (t.a + 1) * t.b, (t.a - 1) * t.b]);
    }
    cand.addAll([ans + 1, ans - 1, ans + 2, ans - 2, ans + 10, ans - 10, ans + 3]);
    final uniq = <int>[];
    for (final c in cand) {
      if (c >= 0 && c != ans && !uniq.contains(c)) uniq.add(c);
    }
    uniq.shuffle(_r);
    final out = uniq.take(3).toList()..add(ans);
    var extra = ans + 4;
    while (out.length < 4) {
      if (!out.contains(extra)) out.add(extra);
      extra++;
    }
    out.shuffle(_r);
    return out;
  }

  /// Tasks for written (column) arithmetic. [digits] = digits of the first number
  /// (for ÷ the dividend); × and ÷ use a one-digit second number (2–9).
  static List<Task> column(Op op, int digits, int count) {
    final lo = pow(10, digits - 1).toInt();
    final hi = pow(10, digits).toInt() - 1;
    final picker = NoRepeat();
    Task make() {
      switch (op) {
        case Op.add:
          return Task(Op.add, rnd(lo, hi), rnd(lo, hi));
        case Op.sub:
          var a = rnd(lo, hi);
          var b = rnd(lo, hi);
          if (a == b) a = a < hi ? a + 1 : a - 1;
          if (a < b) {
            final x = a;
            a = b;
            b = x;
          }
          return Task(Op.sub, a, b);
        case Op.mul:
          return Task(Op.mul, rnd(lo, hi), rnd(2, 9));
        case Op.div:
          // Exact division whose result has no zero digits (no "0 steps" for beginners).
          for (var i = 0; i < 500; i++) {
            final d = rnd(2, 9);
            final q = rnd((lo + d - 1) ~/ d, hi ~/ d);
            if (q < 2 || '$q'.contains('0')) continue;
            final a = q * d;
            if (a < lo || a > hi) continue;
            return Task(Op.div, a, d);
          }
          return digits == 2 ? const Task(Op.div, 84, 4) : (digits == 3 ? const Task(Op.div, 468, 3) : const Task(Op.div, 2448, 4));
      }
    }

    return [for (var i = 0; i < count; i++) picker.pick(make)];
  }
}

String fmtMs(int ms) {
  final t = ms < 0 ? 0 : ms;
  final m = t ~/ 60000;
  final s = (t % 60000) ~/ 1000;
  final d = (t % 1000) ~/ 100;
  return '$m:${s.toString().padLeft(2, '0')},$d';
}

String fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

String fmtShortDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}';
}

/// Number written in words, for the parent gate (101–999, no zero digits).
String numberWords(int n, String lang) {
  final hh = n ~/ 100, tt = (n % 100) ~/ 10, uu = n % 10;
  if (lang == 'de') {
    const u = ['', 'ein', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht', 'neun'];
    const t = ['', 'zehn', 'zwanzig', 'dreißig', 'vierzig', 'fünfzig', 'sechzig', 'siebzig', 'achtzig', 'neunzig'];
    const teen = ['zehn', 'elf', 'zwölf', 'dreizehn', 'vierzehn', 'fünfzehn', 'sechzehn', 'siebzehn', 'achtzehn', 'neunzehn'];
    final parts = <String>[];
    if (hh > 0) parts.add('${u[hh]}hundert');
    if (tt == 1) {
      parts.add(teen[uu]);
    } else if (tt > 1) {
      parts.add(uu > 0 ? '${u[uu]}und${t[tt]}' : t[tt]);
    } else if (uu > 0) {
      parts.add(uu == 1 ? 'eins' : u[uu]);
    }
    return parts.join(' ');
  }
  if (lang == 'es') {
    const h = ['', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos'];
    const u = ['', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'];
    const teen = ['diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve'];
    const veinti = ['veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve'];
    const t = ['', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'];
    final parts = <String>[];
    if (hh > 0) parts.add(hh == 1 && tt == 0 && uu == 0 ? 'cien' : h[hh]);
    if (tt == 1) {
      parts.add(teen[uu]);
    } else if (tt == 2) {
      parts.add(veinti[uu]);
    } else if (tt > 2) {
      parts.add(uu > 0 ? '${t[tt]} y ${u[uu]}' : t[tt]);
    } else if (uu > 0) {
      parts.add(u[uu]);
    }
    return parts.join(' ');
  }
  if (lang == 'fr') {
    const u = ['', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf'];
    const teen = ['dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf'];
    const t = ['', 'dix', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante'];
    String below100(int x) {
      final a = x ~/ 10, b = x % 10;
      if (x < 10) return u[x];
      if (x < 20) return teen[b];
      if (a < 7) return b == 0 ? t[a] : (b == 1 ? '${t[a]} et un' : '${t[a]}-${u[b]}');
      if (a == 7) return b == 1 ? 'soixante et onze' : 'soixante-${teen[b]}';
      if (a == 8) return b == 0 ? 'quatre-vingts' : 'quatre-vingt-${u[b]}';
      return 'quatre-vingt-${teen[b]}';
    }
    final rest = n % 100;
    final parts = <String>[];
    if (hh > 0) parts.add(hh == 1 ? 'cent' : '${u[hh]} cent${rest == 0 ? 's' : ''}');
    if (rest > 0) parts.add(below100(rest));
    return parts.join(' ');
  }
  if (lang == 'uk') {
    const h = ['', 'сто', 'двісті', 'триста', 'чотириста', "п'ятсот", 'шістсот', 'сімсот', 'вісімсот', "дев'ятсот"];
    const t = ['', 'десять', 'двадцять', 'тридцять', 'сорок', "п'ятдесят", 'шістдесят', 'сімдесят', 'вісімдесят', "дев'яносто"];
    const teen = ['десять', 'одинадцять', 'дванадцять', 'тринадцять', 'чотирнадцять', "п'ятнадцять", 'шістнадцять', 'сімнадцять', 'вісімнадцять', "дев'ятнадцять"];
    const u = ['', 'один', 'два', 'три', 'чотири', "п'ять", 'шість', 'сім', 'вісім', "дев'ять"];
    final parts = <String>[];
    if (hh > 0) parts.add(h[hh]);
    if (tt == 1) {
      parts.add(teen[uu]);
    } else {
      if (tt > 0) parts.add(t[tt]);
      if (uu > 0) parts.add(u[uu]);
    }
    return parts.join(' ');
  }
  if (lang == 'pl') {
    const h = ['', 'sto', 'dwieście', 'trzysta', 'czterysta', 'pięćset', 'sześćset', 'siedemset', 'osiemset', 'dziewięćset'];
    const t = ['', 'dziesięć', 'dwadzieścia', 'trzydzieści', 'czterdzieści', 'pięćdziesiąt', 'sześćdziesiąt', 'siedemdziesiąt', 'osiemdziesiąt', 'dziewięćdziesiąt'];
    const teen = ['dziesięć', 'jedenaście', 'dwanaście', 'trzynaście', 'czternaście', 'piętnaście', 'szesnaście', 'siedemnaście', 'osiemnaście', 'dziewiętnaście'];
    const u = ['', 'jeden', 'dwa', 'trzy', 'cztery', 'pięć', 'sześć', 'siedem', 'osiem', 'dziewięć'];
    final parts = <String>[];
    if (hh > 0) parts.add(h[hh]);
    if (tt == 1) {
      parts.add(teen[uu]);
    } else {
      if (tt > 0) parts.add(t[tt]);
      if (uu > 0) parts.add(u[uu]);
    }
    return parts.join(' ');
  }
  const u = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
  const teen = ['ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  const t = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
  final parts = <String>[];
  if (hh > 0) parts.add('${u[hh]} hundred');
  if (tt == 1) {
    parts.add(teen[uu]);
  } else if (tt > 1) {
    parts.add(uu > 0 ? '${t[tt]}-${u[uu]}' : t[tt]);
  } else if (uu > 0) {
    parts.add(u[uu]);
  }
  return parts.join(' ');
}
