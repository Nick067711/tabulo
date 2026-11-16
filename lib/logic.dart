import 'dart:math';

import 'state.dart';

final Random _r = Random();

int rnd(int a, int b) => b <= a ? a : a + _r.nextInt(b - a + 1);

/// Generates tasks for the exercise modules, following the module settings.
class Gen {
  static List<Task> exercise(Op op, ModuleConfig c, int count) {
    final out = <Task>[];
    Task? prev;
    var guard = 0;
    while (out.length < count && guard < count * 50) {
      guard++;
      final t = _one(op, c);
      if (prev != null && prev.same(t)) continue;
      out.add(t);
      prev = t;
    }
    return out;
  }

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
      for (var i = 0; i < 200; i++) {
        final a = rnd(1, max - 1);
        final b = rnd(1, max - a);
        if (!c.carry && max > 10 && (a % 10) + (b % 10) >= 10) continue;
        return Task(Op.add, a, b, missing: missing);
      }
      return Task(Op.add, 1, 1, missing: missing);
    }
    for (var i = 0; i < 200; i++) {
      final a = rnd(2, max);
      final b = rnd(1, a - 1);
      if (!c.carry && max > 10 && (a % 10) < (b % 10)) continue;
      return Task(Op.sub, a, b, missing: missing);
    }
    return Task(Op.sub, 2, 1, missing: missing);
  }

  /// Quiz tasks. Group 0: + and − up to 100, never adding or subtracting 0, 1 or 10.
  /// Group 1: × and ÷ with factors 2–9 (no ×0, ×1, ×10, no n : n).
  static Task quiz(int group, Task? prev) {
    for (var i = 0; i < 100; i++) {
      final t = _quizOne(group);
      if (prev == null || !prev.same(t)) return t;
    }
    return _quizOne(group);
  }

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

  static List<Task> column(Op op, int digits, int count) {
    final lo = pow(10, digits - 1).toInt();
    final hi = pow(10, digits).toInt() - 1;
    final out = <Task>[];
    for (var i = 0; i < count; i++) {
      if (op == Op.add) {
        out.add(Task(Op.add, rnd(lo, hi), rnd(lo, hi)));
      } else {
        var a = rnd(lo, hi);
        var b = rnd(lo, hi);
        if (a == b) a = a < hi ? a + 1 : a - 1;
        if (a < b) {
          final x = a;
          a = b;
          b = x;
        }
        out.add(Task(Op.sub, a, b));
      }
    }
    return out;
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

/// Number written in words, for the parent gate.
String numberWords(int n, String lang) {
  if (lang == 'pl') {
    const h = ['', 'sto', 'dwieście', 'trzysta', 'czterysta', 'pięćset', 'sześćset', 'siedemset', 'osiemset', 'dziewięćset'];
    const t = ['', 'dziesięć', 'dwadzieścia', 'trzydzieści', 'czterdzieści', 'pięćdziesiąt', 'sześćdziesiąt', 'siedemdziesiąt', 'osiemdziesiąt', 'dziewięćdziesiąt'];
    const teen = ['dziesięć', 'jedenaście', 'dwanaście', 'trzynaście', 'czternaście', 'piętnaście', 'szesnaście', 'siedemnaście', 'osiemnaście', 'dziewiętnaście'];
    const u = ['', 'jeden', 'dwa', 'trzy', 'cztery', 'pięć', 'sześć', 'siedem', 'osiem', 'dziewięć'];
    final parts = <String>[];
    final hh = n ~/ 100, tt = (n % 100) ~/ 10, uu = n % 10;
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
  final hh = n ~/ 100, tt = (n % 100) ~/ 10, uu = n % 10;
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
