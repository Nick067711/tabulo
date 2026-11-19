import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../state.dart';
import '../ui.dart';
import 'exercise.dart';

int _pow10(int i) {
  var r = 1;
  for (var k = 0; k < i; k++) {
    r *= 10;
  }
  return r;
}

int _dig(int x, int i) => (x ~/ _pow10(i)) % 10;
int _len(int x) => '$x'.length;

/// Values of the small boxes above the columns: +1 carried when adding, −1 borrowed when subtracting.
const markPlus = '+1';
const markMinus = '−1';

/// Written addition, subtraction and multiplication by a one-digit number.
/// Cells: r{i} result digits (i = column from the right), c{i} small boxes above column i.
class ColumnPlan {
  final Task task;
  final int width;
  final Map<String, String> expected;
  final List<int> carryIn; // what comes into each column from the one on its right
  final List<String> order;
  ColumnPlan._(this.task, this.width, this.expected, this.carryIn, this.order);

  factory ColumnPlan(Task t) {
    final res = t.result;
    final numLen = math.max(_len(t.a), t.op == Op.mul ? 1 : _len(t.b));
    final w = math.max(numLen, _len(res));
    final exp = <String, String>{};
    final carryIn = <int>[];
    var carry = 0;
    for (var i = 0; i < w; i++) {
      carryIn.add(carry);
      // A small box only above columns that still have digits of the numbers. Over an empty
      // column the carried value is written straight into the result.
      if (i > 0 && i < numLen) {
        exp['c$i'] = carry == 0
            ? ''
            : switch (t.op) {
                Op.add => markPlus,
                Op.sub => markMinus,
                _ => '$carry',
              };
      }
      final da = _dig(t.a, i), db = _dig(t.b, i);
      if (t.op == Op.add) {
        carry = da + db + carry >= 10 ? 1 : 0;
      } else if (t.op == Op.sub) {
        carry = da - carry < db ? 1 : 0;
      } else {
        carry = (da * t.b + carry) ~/ 10;
      }
      exp['r$i'] = (i == 0 || res >= _pow10(i)) ? '${_dig(res, i)}' : '';
    }
    final order = <String>[];
    for (var i = 0; i < w; i++) {
      order.add('r$i');
      if (exp.containsKey('c${i + 1}')) order.add('c${i + 1}');
    }
    return ColumnPlan._(t, w, exp, carryIn, order);
  }

  bool isRight(String cell, String value) {
    final e = expected[cell] ?? '';
    if (e.isEmpty) return value.isEmpty || value == '0';
    return value == e;
  }
}

/// Multiplication by a two-digit number: two partial products, then their sum.
/// Cells: m0_{i}, m1_{i} (rows of partial products, i = column from the right), s_{i} the sum,
/// k{r}_{j} small boxes for the carries of row r, above digit j of the top number. The boxes
/// show the carries of the row being worked on, so they are empty again for the second row.
class LongMulPlan {
  final Task task;
  final int width;
  final Map<String, String> expected;
  final Map<String, int> carryIn;
  final List<String> order;
  LongMulPlan._(this.task, this.width, this.expected, this.carryIn, this.order);

  factory LongMulPlan(Task t) {
    final bd = [t.b % 10, t.b ~/ 10];
    final prods = [t.a * bd[0], t.a * bd[1]];
    final sum = t.a * t.b;
    final aLen = _len(t.a);
    final w = math.max(_len(sum), math.max(_len(prods[0]), _len(prods[1]) + 1));
    final exp = <String, String>{};
    final cin = <String, int>{};
    final order = <String>[];
    for (var r = 0; r < 2; r++) {
      var carry = 0;
      for (var j = 0; j < _len(prods[r]); j++) {
        if (j > 0 && j < aLen && bd[r] > 0) {
          final k = 'k${r}_$j';
          exp[k] = carry == 0 ? '' : '$carry';
          order.add(k);
        }
        final id = 'm${r}_${j + r}';
        exp[id] = '${_dig(prods[r], j)}';
        cin[id] = carry;
        carry = (_dig(t.a, j) * bd[r] + carry) ~/ 10;
        order.add(id);
      }
    }
    var carry = 0;
    for (var i = 0; i < _len(sum); i++) {
      final id = 's_$i';
      exp[id] = '${_dig(sum, i)}';
      cin[id] = carry;
      final v = _dig(prods[0], i) + (i >= 1 ? _dig(prods[1], i - 1) : 0) + carry;
      carry = v ~/ 10;
      order.add(id);
    }
    return LongMulPlan._(t, w, exp, cin, order);
  }

  int prod(int r) => task.a * (r == 0 ? task.b % 10 : task.b ~/ 10);

  /// Carry boxes are a help for the child and are not marked as mistakes.
  bool isRight(String id, String v) => id.startsWith('k') || v == (expected[id] ?? '');

  /// Row (0 or 1) whose carries are shown above the top number, or null while adding.
  static int? rowOf(String? id) {
    if (id == null || id.startsWith('s')) return null;
    return id[1] == '0' ? 0 : 1;
  }
}

/// One step of long division: how many times the divisor fits into [cur].
class DivStep {
  final int pos; // index (from the left) of the last dividend digit used in this step
  final int cur, q, prod, rem;
  const DivStep(this.pos, this.cur, this.q, this.prod, this.rem);
}

// When the next number would be smaller than the divisor, the 0 of the result is written in
// the same step: 612 : 3 → 61 : 3 = 20, 61 − 60 = 1, bring down 2 → 12 : 3 = 4.

/// Long division. Fields q{k} (quotient digit), p{k} (product), r{k} (difference) of step k;
/// each field has one box per digit: "p0.0", "p0.1"…, filled from the left.
class DivPlan {
  final Task task;
  final List<int> digits;
  final List<DivStep> steps;
  final int firstPos; // dividend digit above which the first digit of the result stands
  final Map<String, int> fieldLen;
  final Map<String, String> expected; // per box
  final List<String> order;
  DivPlan._(this.task, this.digits, this.steps, this.firstPos, this.fieldLen, this.expected, this.order);

  factory DivPlan(Task t) {
    final ds = '${t.a}'.split('').map(int.parse).toList();
    final d = t.b;
    var pos = 0;
    var cur = ds[0];
    while (cur < d && pos < ds.length - 1) {
      pos++;
      cur = cur * 10 + ds[pos];
    }
    final firstPos = pos;
    final steps = <DivStep>[];
    while (true) {
      var q = cur ~/ d;
      while (pos + 1 < ds.length && (cur - q * d) * 10 + ds[pos + 1] < d) {
        pos++;
        cur = cur * 10 + ds[pos];
        q = cur ~/ d;
      }
      final p = q * d;
      final r = cur - p;
      steps.add(DivStep(pos, cur, q, p, r));
      if (pos + 1 >= ds.length) break;
      pos++;
      cur = r * 10 + ds[pos];
    }
    final flen = <String, int>{};
    final exp = <String, String>{};
    final order = <String>[];
    void add(String f, String value, int len) {
      flen[f] = len;
      for (var j = 0; j < len; j++) {
        final id = '$f.$j';
        exp[id] = value.isEmpty ? '' : value[j];
        order.add(id);
      }
    }

    for (var k = 0; k < steps.length; k++) {
      final s = steps[k];
      final last = k == steps.length - 1;
      add('q$k', '${s.q}', _len(s.q));
      add('p$k', '${s.prod}', _len(s.prod));
      // An intermediate difference of 0 may be left empty.
      add('r$k', !last && s.rem == 0 ? '' : '${s.rem}', _len(s.rem));
    }
    return DivPlan._(t, ds, steps, firstPos, flen, exp, order);
  }

  bool isRight(String id, String value) {
    final e = expected[id] ?? '';
    if (e.isEmpty) return value.isEmpty || value == '0';
    return value == e;
  }
}

class ColumnScreen extends StatefulWidget {
  final List<Task>? tasks;
  const ColumnScreen({super.key, this.tasks});
  @override
  State<ColumnScreen> createState() => _ColumnScreenState();
}

class _ColumnScreenState extends State<ColumnScreen> {
  Op _op = Op.add;
  int _digits = 3;
  bool _two = false; // × / ÷ by a two-digit number
  bool _rem = false; // ÷ with a remainder
  bool _custom = false; // a task typed in by the child (e.g. copied from a notebook)
  bool _started = false;
  List<Task> _tasks = [];
  int _idx = 0;
  ColumnPlan? _plan;
  LongMulPlan? _lm;
  DivPlan? _div;
  final Map<String, String> _vals = {};
  String? _sel;
  bool _checked = false;
  bool _failedThis = false;
  bool _solved = false;
  int _nextIn = 0; // seconds left before the next task opens by itself
  final List<Mistake> _mistakes = [];
  int _good = 0;
  int _start = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.tasks != null && widget.tasks!.isNotEmpty) {
      _begin(List.of(widget.tasks!));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Task get _task => _tasks[_idx];
  List<String> get _order => _div?.order ?? _lm?.order ?? _plan!.order;
  Map<String, String> get _expected => _div?.expected ?? _lm?.expected ?? _plan!.expected;
  bool _right(String id, String v) =>
      _div != null ? _div!.isRight(id, v) : (_lm != null ? _lm!.isRight(id, v) : _plan!.isRight(id, v));

  void _begin(List<Task> tasks) {
    _tasks = tasks;
    _idx = 0;
    _good = 0;
    _mistakes.clear();
    _started = true;
    _start = DateTime.now().millisecondsSinceEpoch;
    _load();
  }

  void _load() {
    final t = _task;
    _plan = null;
    _lm = null;
    _div = null;
    if (t.op == Op.div) {
      _div = DivPlan(t);
    } else if (t.op == Op.mul && t.b >= 10) {
      _lm = LongMulPlan(t);
    } else {
      _plan = ColumnPlan(t);
    }
    _sel = _order.first;
    _vals.clear();
    _checked = false;
    _failedThis = false;
    _solved = false;
  }

  /// Back during an exercise returns to the choice of operation, not to the main menu.
  void _backToSetup() {
    _timer?.cancel();
    setState(() => _started = false);
  }

  /// The +1 / −1 buttons are for addition and subtraction only.
  bool get _usesMarkBar => _plan != null && (_task.op == Op.add || _task.op == Op.sub);
  bool get _onMark => (_sel ?? '').startsWith('c');

  void _advance(String from) {
    final i = _order.indexOf(from);
    if (i >= 0 && i + 1 < _order.length) _sel = _order[i + 1];
  }

  /// Digit from the keypad: one digit per box, then on to the next box.
  void _type(String d) {
    final s = _sel;
    if (s == null || _solved) return;
    final lm = _lm;
    if (lm != null) {
      setState(() {
        _vals[s] = d;
        _checked = false;
        if (s.startsWith('m')) {
          final r = s[1] == '0' ? 0 : 1;
          final j = int.parse(s.split('_')[1]) - r;
          final k = 'k${r}_${j + 1}';
          if (lm.expected.containsKey(k)) {
            // Nothing to carry and the digit is right: skip the small box.
            final empty = (lm.expected[k] ?? '').isEmpty;
            _sel = empty && lm.isRight(s, d) ? 'm${r}_${j + 1 + r}' : k;
            return;
          }
        }
        _advance(s);
      });
      return;
    }
    final plan = _plan;
    if (plan == null) {
      setState(() {
        _vals[s] = d;
        _checked = false;
        _advance(s);
      });
      return;
    }
    // In + and − the small boxes take only +1 / −1 from their own buttons.
    if (s.startsWith('c') && _usesMarkBar) return;
    setState(() {
      _vals[s] = d;
      _checked = false;
      final col = int.tryParse(s.substring(1)) ?? 0;
      if (s.startsWith('c')) {
        _sel = 'r$col'; // carried digit written (×): on to the result box below it
        return;
      }
      if (col + 1 >= plan.width) return;
      final hasMark = plan.expected.containsKey('c${col + 1}');
      final noMark = (plan.expected['c${col + 1}'] ?? '').isEmpty;
      // No small box, or nothing to carry and the digit is right: straight to the next result box.
      _sel = !hasMark || (noMark && plan.isRight(s, d)) ? 'r${col + 1}' : 'c${col + 1}';
    });
  }

  /// Backspace: clears the selected box; on an empty box it steps back to the previous one.
  void _delete() {
    final s = _sel;
    if (s == null || _solved) return;
    if (s.startsWith('c') && _usesMarkBar) return;
    setState(() {
      _checked = false;
      if ((_vals[s] ?? '').isNotEmpty) {
        _vals.remove(s);
        return;
      }
      final i = _order.indexOf(s);
      if (i > 0) {
        _sel = _order[i - 1];
        _vals.remove(_sel);
      }
    });
  }

  /// +1 / −1 (or empty) in the selected small box, then on to the result box below-left.
  void _mark(String v) {
    final s = _sel;
    if (s == null || _solved || !s.startsWith('c')) return;
    setState(() {
      if (v.isEmpty || _vals[s] == v) {
        _vals.remove(s);
      } else {
        _vals[s] = v;
      }
      _checked = false;
      if (v.isNotEmpty) _sel = 'r${s.substring(1)}';
    });
  }

  void _moveNext() {
    final s = _sel ?? _order.first;
    final i = _order.indexOf(s);
    setState(() => _sel = _order[(i + 1) % _order.length]);
  }

  void _next() {
    _timer?.cancel();
    if (!mounted) return;
    if (_custom) {
      _askCustom();
      return;
    }
    if (_idx + 1 >= _tasks.length) {
      _finish();
    } else {
      setState(() {
        _idx++;
        _load();
      });
    }
  }

  void _check() {
    if (_solved) {
      _next();
      return;
    }
    var all = true;
    for (final k in _expected.keys) {
      if (!_right(k, _vals[k] ?? '')) all = false;
    }
    setState(() {
      _checked = true;
      if (all) {
        _solved = true;
        if (!_failedThis) _good++;
      } else {
        if (!_failedThis) {
          _failedThis = true;
          _mistakes.add(Mistake(_task, ''));
        }
      }
    });
    // The solution stays on screen until "Next" is tapped, unless Settings say otherwise.
    if (all && !_custom && AppScope.read(context).columnAuto) {
      _nextIn = AppScope.read(context).columnDelayS;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
        if (!mounted) {
          tm.cancel();
          return;
        }
        if (_nextIn <= 1) {
          tm.cancel();
          _next();
        } else {
          setState(() => _nextIn--);
        }
      });
    }
  }

  /// The child types in their own task, e.g. copied from a notebook. The operation is the one
  /// chosen on the setup screen (or of the custom task being solved).
  Future<void> _askCustom() async {
    final app = AppScope.read(context);
    final op = _custom && _started ? _task.op : _op;
    final ca = TextEditingController();
    final cb = TextEditingController();
    String? err;
    Widget numField(TextEditingController c, int maxLen) => SizedBox(
          width: 104,
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: maxLen,
            textAlign: TextAlign.center,
            style: ts(24),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: C.op(op), width: 3)),
            ),
          ),
        );
    final task = await showDialog<Task>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          void submit() {
            final a = int.tryParse(ca.text);
            final b = int.tryParse(cb.text);
            String? e;
            if (a == null || b == null || a < 1 || b < 1) {
              e = 'custom_err_empty';
            } else if ((op == Op.mul || op == Op.div) && b > 99) {
              e = 'custom_err_two';
            } else if (op == Op.sub && a < b) {
              e = 'custom_err_sub';
            } else if (op == Op.div && a < b) {
              e = 'custom_err_div';
            }
            if (e != null) {
              setD(() => err = app.t(e!));
              return;
            }
            Navigator.of(ctx).pop(Task(op, a!, b!));
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(app.t('custom_title'), style: ts(20)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(app.t('custom_info'), style: ts(14, color: C.inkSoft, weight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                numField(ca, 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(app.sign(op), style: ts(30, color: C.op(op))),
                ),
                numField(cb, op == Op.mul || op == Op.div ? 2 : 5),
              ]),
              if (err != null) ...[
                const SizedBox(height: 12),
                Text(err!, style: ts(14, color: C.red, weight: FontWeight.w800)),
              ],
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(app.t('cancel'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.op(op)),
                onPressed: submit,
                child: Text(app.t('start')),
              ),
            ],
          );
        },
      ),
    );
    ca.dispose();
    cb.dispose();
    if (!mounted) return;
    if (task == null) {
      // Cancelled while a custom task was open: back to the setup screen.
      if (_custom && _started) _backToSetup();
      return;
    }
    setState(() {
      _custom = true;
      _begin([task]);
    });
  }

  String _setupDesc(AppState app) {
    final parts = [app.opName(_op), app.t('digits_n').replaceAll('{n}', '$_digits')];
    if (_op == Op.mul || _op == Op.div) parts.add(app.t(_two ? 'by_two_digit' : 'by_one_digit'));
    if (_op == Op.div && _rem) parts.add(app.t('with_rem'));
    return parts.join(' · ');
  }

  void _finish() {
    final app = AppScope.read(context);
    final s = Session(
      id: app.newId(),
      profileId: app.me.id,
      kind: 'column',
      date: app.now,
      ms: DateTime.now().millisecondsSinceEpoch - _start,
      total: _tasks.length,
      correct: _good,
      mistakes: List.of(_mistakes),
      desc: widget.tasks != null ? app.t('retry_desc') : _setupDesc(app),
      stars: starsFor(_good, _tasks.length),
    );
    app.addSession(s);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SummaryScreen(
        session: s,
        retry: s.mistakes.isEmpty ? null : () => ColumnScreen(tasks: s.mistakes.map((m) => m.task).toList()),
      ),
    ));
  }

  // ---------------- hints ----------------

  String _mulExpr(AppState app, int da, int b, int carry) {
    final m = app.sign(Op.mul);
    final p = da * b;
    return carry > 0 ? '$da $m $b = $p, $p + $carry = ${p + carry}' : '$da $m $b = $p';
  }

  String _hint(AppState app) {
    if (_div != null) return _divHint(app);
    if (_lm != null) return _lmHint(app);
    final plan = _plan!;
    final t = plan.task;
    final sel = _sel ?? 'r0';
    if (sel.startsWith('c')) {
      return app.t(switch (t.op) {
        Op.add => 'hint_mark_add',
        Op.sub => 'hint_mark_sub',
        _ => 'hint_mark_mul',
      });
    }
    final col = (int.tryParse(sel.substring(1)) ?? 0).clamp(0, plan.width - 1);
    final cin = plan.carryIn[col];
    final da = _dig(t.a, col), db = _dig(t.b, col);
    final numLen = math.max(_len(t.a), t.op == Op.mul ? 1 : _len(t.b));
    if (col >= numLen) return app.t('hint_mul_last').replaceAll('{c}', '$cin');
    if (t.op == Op.mul) {
      final v = da * t.b + cin;
      final e = _mulExpr(app, da, t.b, cin);
      if (v >= 10) {
        final key = col + 1 < numLen ? 'hint_mul_carry' : 'hint_lm_carry';
        return app.t(key).replaceAll('{e}', e).replaceAll('{d}', '${v % 10}').replaceAll('{c}', '${v ~/ 10}');
      }
      return app.t('hint_mul').replaceAll('{e}', e);
    }
    if (t.op == Op.add) {
      final s = da + db + cin;
      final plus = cin == 1 ? ' + 1' : '';
      if (s >= 10) {
        final key = col + 1 < numLen ? 'hint_add_carry' : 'hint_add_carry_end';
        return app.t(key).replaceAll('{e}', '$da + $db$plus = $s').replaceAll('{d}', '${s % 10}');
      }
      return app.t('hint_add').replaceAll('{e}', '$da + $db$plus = $s');
    }
    final top = da - cin;
    if (top < db) {
      return app.t('hint_sub_borrow').replaceAll('{e}', '${top + 10} − $db = ${top + 10 - db}');
    }
    return app.t('hint_sub').replaceAll('{e}', '$top − $db = ${top - db}');
  }

  String _lmHint(AppState app) {
    final plan = _lm!;
    final t = plan.task;
    final sel = _sel ?? plan.order.first;
    final cin = plan.carryIn[sel] ?? 0;
    if (sel.startsWith('k')) return app.t('hint_mark_mul');
    if (sel.startsWith('m')) {
      final r = sel[1] == '0' ? 0 : 1;
      final col = int.parse(sel.split('_')[1]);
      final j = col - r;
      final bd = r == 0 ? t.b % 10 : t.b ~/ 10;
      final pre = r == 1 && j == 0 ? '${app.t('hint_lm_shift')} ' : '';
      if (j >= _len(t.a)) return pre + app.t('hint_mul_last').replaceAll('{c}', '$cin');
      final da = _dig(t.a, j);
      final v = da * bd + cin;
      final e = _mulExpr(app, da, bd, cin);
      if (v >= 10) {
        final key = plan.expected.containsKey('k${r}_${j + 1}') ? 'hint_mul_carry' : 'hint_lm_carry';
        return pre + app.t(key).replaceAll('{e}', e).replaceAll('{d}', '${v % 10}').replaceAll('{c}', '${v ~/ 10}');
      }
      return pre + app.t('hint_lm').replaceAll('{e}', e);
    }
    final i = int.parse(sel.split('_')[1]);
    final p0 = plan.prod(0), p1 = plan.prod(1);
    final terms = <int>[];
    if (i < _len(p0)) terms.add(_dig(p0, i));
    if (i >= 1 && i - 1 < _len(p1)) terms.add(_dig(p1, i - 1));
    if (terms.isEmpty) return app.t('hint_mul_last').replaceAll('{c}', '$cin');
    if (cin > 0) terms.add(cin);
    final v = terms.reduce((a, b) => a + b);
    final e = '${terms.join(' + ')} = $v';
    if (v >= 10 && i + 1 < _len(t.a * t.b)) {
      return app.t('hint_ls_carry').replaceAll('{e}', e).replaceAll('{d}', '${v % 10}');
    }
    return app.t('hint_ls').replaceAll('{e}', e);
  }

  String _divHint(AppState app) {
    final plan = _div!;
    final f = (_sel ?? 'q0').split('.').first;
    final k = (int.tryParse(f.substring(1)) ?? 0).clamp(0, plan.steps.length - 1);
    final s = plan.steps[k];
    final d = plan.task.b;
    if (f.startsWith('q')) {
      return app.t(_len(s.q) > 1 ? 'hint_div_q0' : 'hint_div_q').replaceAll('{d}', '$d').replaceAll('{n}', '${s.cur}');
    }
    if (f.startsWith('p')) {
      return app.t('hint_div_p').replaceAll('{e}', '${s.q} ${app.sign(Op.mul)} $d').replaceAll('{n}', '${s.cur}');
    }
    if (k < plan.steps.length - 1) return app.t('hint_div_r').replaceAll('{e}', '${s.cur} − ${s.prod}');
    final hasRem = plan.task.a % d != 0;
    return app.t(hasRem ? 'hint_div_last_rem' : 'hint_div_last').replaceAll('{e}', '${s.cur} − ${s.prod}');
  }

  // ---------------- screens ----------------

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!_started) return _setup(app);
    final inRetry = widget.tasks != null;
    return PopScope(
      canPop: inRetry,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToSetup();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(
                  title: app.t('column_title'),
                  actions: [Text('${_idx + 1}/${_tasks.length}', style: ts(16, color: C.inkSoft))],
                ),
                const SizedBox(height: 10),
                CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: C.pink),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_hint(app), style: ts(15, weight: FontWeight.w800, height: 1.35))),
                  ]),
                ),
                const SizedBox(height: 10),
                if (_usesMarkBar) ...[
                  _markBar(app),
                  const SizedBox(height: 6),
                ],
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _div != null ? _divBoard(app) : (_lm != null ? _lmBoard(app) : _board(app)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Keypad(
                  wide: true,
                  keyHeight: 54,
                  onDigit: _type,
                  onDelete: _delete,
                  onOk: _check,
                  extraIcon: Icons.arrow_forward_rounded,
                  onExtra: _moveNext,
                ),
                const SizedBox(height: 4),
                Chunky(
                  height: 58,
                  color: _solved ? C.green : C.pink,
                  shadow: _solved ? C.greenD : C.pinkD,
                  radius: 20,
                  depth: 6,
                  onTap: _check,
                  child: _solved
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('✓ ${app.t('bravo')} ${app.fullText(_task)}',
                              style: ts(16, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                              _custom
                                  ? '${app.t('new_custom')}  ›'
                                  : (app.columnAuto ? '${app.t('next')}  ›  ($_nextIn)' : '${app.t('next')}  ›'),
                              style: ts(20, color: Colors.white)),
                        ])
                      : Text(_checked ? '✗ ${app.t('fix_red')}' : 'OK', style: ts(20, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Buttons for the small boxes above the columns. Active only when such a box is selected.
  Widget _markBar(AppState app) {
    final on = _onMark && !_solved;
    Widget btn(String v, String label, Color c, Color d) => Expanded(
          child: Opacity(
            opacity: on ? 1 : 0.35,
            child: Chunky(
              height: 46,
              color: c,
              shadow: d,
              radius: 14,
              depth: 4,
              onTap: on ? () => _mark(v) : null,
              child: Text(label, textScaler: TextScaler.noScaling, style: tsBox(22, color: Colors.white)),
            ),
          ),
        );
    return Row(children: [
      Expanded(
        flex: 2,
        child: Text(app.t(on ? 'mark_pick' : 'mark_info'),
            style: ts(13, color: C.inkSoft, weight: FontWeight.w700, height: 1.25)),
      ),
      const SizedBox(width: 8),
      // Same colour for both, so the colour does not give the answer away.
      btn(markPlus, markPlus, C.purple, C.purpleD),
      const SizedBox(width: 8),
      btn(markMinus, markMinus, C.purple, C.purpleD),
      const SizedBox(width: 8),
      SizedBox(
        width: 52,
        child: Opacity(
          opacity: on ? 1 : 0.35,
          child: Chunky(
            height: 46,
            color: Colors.white,
            shadow: C.line,
            radius: 14,
            depth: 4,
            onTap: on ? () => _mark('') : null,
            child: const Icon(Icons.backspace_outlined, color: C.ink, size: 22),
          ),
        ),
      ),
    ]);
  }

  Widget _setup(AppState app) {
    final digitsLabel = switch (_op) {
      Op.mul => app.t('digits_mul'),
      Op.div => app.t('digits_div'),
      _ => app.t('how_many_digits'),
    };
    final info = switch (_op) {
      Op.mul => app.t(_two ? 'column_info_lm' : 'column_info_mul'),
      Op.div => app.t('column_info_div'),
      _ => app.t('column_info'),
    };
    Widget opPick(Op op) => Pick(
          label: '${app.sign(op)}  ${app.opName(op)}',
          on: _op == op,
          color: C.op(op),
          dark: C.opD(op),
          height: 56,
          fontSize: 16,
          onTap: () => setState(() => _op = op),
        );
    Widget pinkPick(String label, bool on, VoidCallback tap) =>
        Pick(label: label, on: on, color: C.pink, dark: C.pinkD, height: 52, fontSize: 16, onTap: tap);
    final mulDiv = _op == Op.mul || _op == Op.div;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(title: app.t('column_title')),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 16),
                    SectionLabel(app.t('which_op')),
                    Gap(children: [opPick(Op.add), opPick(Op.sub)]),
                    const SizedBox(height: 4),
                    Gap(children: [opPick(Op.mul), opPick(Op.div)]),
                    const SizedBox(height: 16),
                    SectionLabel(digitsLabel),
                    Gap(children: [
                      for (final d in [2, 3, 4])
                        pinkPick(app.t('digits_n').replaceAll('{n}', '$d'), _digits == d, () => setState(() => _digits = d)),
                    ]),
                    if (mulDiv) ...[
                      const SizedBox(height: 14),
                      SectionLabel(app.t(_op == Op.div ? 'divisor_label' : 'second_number')),
                      Gap(children: [
                        pinkPick(app.t('one_digit'), !_two, () => setState(() => _two = false)),
                        pinkPick(app.t('two_digit'), _two, () => setState(() => _two = true)),
                      ]),
                    ],
                    if (_op == Op.div) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line, width: 2)),
                        child: Row(children: [
                          Expanded(child: Text(app.t('remainder_mode'), style: ts(15))),
                          Switch(
                            value: _rem,
                            activeTrackColor: C.purple,
                            onChanged: (v) => setState(() => _rem = v),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CardBox(
                      child: Text(info, style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.4)),
                    ),
                    const SizedBox(height: 16),
                    Chunky(
                      height: 56,
                      radius: 18,
                      depth: 4,
                      border: C.line,
                      onTap: _askCustom,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.edit_note_rounded, color: C.ink, size: 28),
                        const SizedBox(width: 8),
                        Flexible(child: Text('${app.t('custom_btn')}  ${app.sign(_op)}', style: ts(16))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              Chunky(
                height: 66,
                color: C.pink,
                shadow: C.pinkD,
                radius: 22,
                depth: 7,
                onTap: () => setState(() {
                  _custom = false;
                  _begin(Gen.column(_op, _digits, 5, two: mulDiv && _two, rem: _op == Op.div && _rem));
                }),
                child: Text(app.t('start'), style: ts(24, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Colours of an input box: normal, selected, checked right or wrong.
  ({Color border, Color bg, Color fg, bool dashed}) _look(String id, String v, {bool small = false}) {
    Color border = small ? const Color(0xFFC9B48F) : C.line;
    Color bg = Colors.white;
    Color fg = small ? C.pink : C.ink;
    var dashed = v.isEmpty;
    if (_checked) {
      if (!_right(id, v)) {
        border = C.red;
        bg = C.redBg;
        fg = C.red;
        dashed = false;
      } else if (v.isNotEmpty) {
        border = C.green;
        bg = C.greenBg;
        fg = C.greenD;
      }
    }
    if (_sel == id && !_solved) {
      border = C.pink;
      bg = const Color(0xFFFFF0F5);
      fg = C.pink;
    }
    return (border: border, bg: bg, fg: fg, dashed: dashed);
  }

  /// An input box placed at an exact spot (used by the long × and ÷ boards).
  Widget _box(String id, double left, double top, double w, double h, double font) {
    final v = _vals[id] ?? '';
    final sel = _sel == id;
    final look = _look(id, v);
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: GestureDetector(
        onTap: () => setState(() => _sel = id),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: look.dashed && !sel ? Colors.transparent : look.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: look.border, width: sel || _checked ? 3 : 2),
          ),
          child: Text(v, textScaler: TextScaler.noScaling, style: tsBox(font, color: look.fg)),
        ),
      ),
    );
  }

  // ---------------- + − and × by one digit ----------------

  Widget _board(AppState app) {
    final plan = _plan!;
    final t = plan.task;
    final w = plan.width;
    const colW = 64.0;
    final sign = app.sign(t.op);

    Widget cellBox(String id, {bool small = false}) {
      final v = _vals[id] ?? '';
      final sel = _sel == id;
      final look = _look(id, v, small: small);
      final size = small ? 46.0 : 56.0;
      return GestureDetector(
        onTap: () => setState(() => _sel = id),
        child: Container(
          width: size,
          height: small ? 40 : 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: look.dashed && !sel ? Colors.transparent : look.bg,
            borderRadius: BorderRadius.circular(small ? 10 : 16),
            border: Border.all(color: look.border, width: sel || _checked ? 3 : 2),
          ),
          child: Text(v, textScaler: TextScaler.noScaling, style: tsBox(small ? 20 : 38, color: look.fg)),
        ),
      );
    }

    Widget digit(int x, int i) {
      final show = i == 0 || x >= _pow10(i);
      return SizedBox(height: 60, child: Center(child: Text(show ? '${_dig(x, i)}' : '', style: ts(46))));
    }

    final cols = <Widget>[];
    // sign column
    cols.add(SizedBox(
      width: 48,
      child: Column(children: [
        const SizedBox(height: 44),
        const SizedBox(height: 60),
        SizedBox(height: 60, child: Center(child: Text(sign, style: ts(46, color: C.pink)))),
        const SizedBox(height: 18),
        const SizedBox(height: 64),
      ]),
    ));
    final selCol = int.tryParse((_sel ?? 'r0').substring(1)) ?? 0;
    for (var i = w - 1; i >= 0; i--) {
      cols.add(Container(
        width: colW,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: i == selCol && !_solved ? const Color(0xFFFFE3EC) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          SizedBox(height: 44, child: Center(child: plan.expected.containsKey('c$i') ? cellBox('c$i', small: true) : null)),
          digit(t.a, i),
          digit(t.b, i),
          const SizedBox(height: 18),
          cellBox('r$i'),
        ]),
      ));
    }
    return Stack(children: [
      Row(mainAxisSize: MainAxisSize.min, children: cols),
      Positioned(
        left: 30,
        right: 0,
        top: 6 + 44 + 60 + 60 + 7,
        child: Container(height: 4, decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(2))),
      ),
    ]);
  }

  // ---------------- × by two digits ----------------

  Widget _lmBoard(AppState app) {
    final plan = _lm!;
    final t = plan.task;
    final w = plan.width;
    const cw = 54.0;
    const rh = 58.0;
    const kh = 44.0; // height of the row of carry boxes
    double x(int col) => (w - col) * cw; // column 0 is the rightmost; one free column on the left for the signs
    double y(num row) => kh + row * rh; // row 0 = top number
    final items = <Widget>[];

    Widget text(double left, num row, String s, {Color color = C.ink, double size = 38}) => Positioned(
          left: left,
          top: y(row),
          width: cw,
          height: rh,
          child: Center(child: Text(s, textScaler: TextScaler.noScaling, style: tsBox(size, color: color))),
        );
    Widget line(num row) => Positioned(
          left: x(w) + 4,
          top: y(row) - 2,
          width: (w + 1) * cw - 8,
          height: 4,
          child: Container(decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(2))),
        );

    // Carry boxes of the row being worked on (empty again when the second row starts).
    final row = LongMulPlan.rowOf(_sel);
    if (row != null) {
      for (var j = 1; j < _len(t.a); j++) {
        final id = 'k${row}_$j';
        if (plan.expected.containsKey(id)) items.add(_box(id, x(j) + 7, 2, cw - 14, kh - 6, 20));
      }
    }
    for (var i = 0; i < _len(t.a); i++) {
      items.add(text(x(i), 0, '${_dig(t.a, i)}'));
    }
    for (var i = 0; i < _len(t.b); i++) {
      items.add(text(x(i), 1, '${_dig(t.b, i)}'));
    }
    items.add(text(x(w), 1, app.sign(Op.mul), color: C.pink));
    items.add(line(2));
    for (final id in plan.order) {
      if (id.startsWith('k')) continue;
      final r = id.startsWith('m0') ? 2 : (id.startsWith('m1') ? 3 : 4);
      final col = int.parse(id.split('_')[1]);
      items.add(_box(id, x(col) + 3, y(r) + 4, cw - 6, rh - 8, 30));
    }
    items.add(text(x(w), 3, '+', color: C.pink));
    items.add(line(4));
    return SizedBox(width: x(-1), height: y(5), child: Stack(clipBehavior: Clip.none, children: items));
  }

  // ---------------- ÷ (long division) ----------------

  /// Layouts (Settings › General): pl – result above the line over the dividend, ": d" beside it;
  /// en – divisor and bracket on the left, result above; de – "a : d = result" in one line;
  /// pot – divisor on the right in a corner, result under it (France, Spain, Ukraine).
  Widget _divBoard(AppState app) {
    final plan = _div!;
    final layout = app.divLayout;
    final n = plan.digits.length;
    final qn = plan.steps.length;
    final qTotal = n - plan.firstPos; // digits of the result
    final dv = '${plan.task.b}';
    final dl = dv.length;
    const cw = 44.0;
    const rh = 46.0;
    final left = layout == 'en' ? dl + 2 : 1; // columns kept free on the left (minus signs, divisor)
    final top = layout == 'pl' || layout == 'en' ? 1 : 0; // row of the dividend
    final base = top + 1; // first row of the steps
    final rightCols = switch (layout) {
      'pl' => n + 1 + dl,
      'de' => n + 2 + dl + qTotal,
      'pot' => n + math.max(qTotal, dl) + 1,
      _ => n,
    };
    final rows = base + 2 * qn;
    double x(num col) => (col + left) * cw;
    double y(num row) => row * rh;
    final items = <Widget>[];

    Widget text(double l, num row, String s, {Color color = C.ink, double size = 32}) => Positioned(
          left: l,
          top: y(row),
          width: cw,
          height: rh,
          child: Center(child: Text(s, textScaler: TextScaler.noScaling, style: tsBox(size, color: color))),
        );

    Widget hLine(num fromCol, num toCol, num atRow, {double thick = 3}) => Positioned(
          left: x(fromCol) + 2,
          top: y(atRow) - thick / 2,
          width: (toCol - fromCol) * cw - 4,
          height: thick,
          child: Container(decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(2))),
        );

    /// A field: one box per digit, ending at column [endCol], filled from the left.
    void field(String f, int endCol, num row, {double dx = 0}) {
      final len = plan.fieldLen[f] ?? 1;
      final start = endCol - len + 1;
      for (var j = 0; j < len; j++) {
        items.add(_box('$f.$j', x(start + j) + 2 + dx, y(row) + 3, cw - 4, rh - 6, 26));
      }
    }

    // dividend
    for (var i = 0; i < n; i++) {
      items.add(text(x(i), top, '${plan.digits[i]}'));
    }
    final divSign = app.sign(Op.div);
    switch (layout) {
      case 'pl':
        items.add(text(x(n), top, divSign, color: C.pink));
        for (var j = 0; j < dl; j++) {
          items.add(text(x(n + 1 + j), top, dv[j]));
        }
        items.add(hLine(0, n, top));
      case 'en':
        for (var j = 0; j < dl; j++) {
          items.add(text(x(-1 - dl + j), top, dv[j]));
        }
        items.add(text(x(-1), top, ')', size: 40));
        items.add(hLine(0, n, top));
      case 'de':
        items.add(text(x(n), top, divSign, color: C.pink));
        for (var j = 0; j < dl; j++) {
          items.add(text(x(n + 1 + j), top, dv[j]));
        }
        items.add(text(x(n + 1 + dl), top, '=', color: C.pink));
      default: // pot
        items.add(Positioned(left: x(n) + 6, top: y(top) + 4, width: 3, height: rh * 2 - 8, child: Container(color: C.ink)));
        for (var j = 0; j < dl; j++) {
          items.add(text(x(n + j) + 12, top, dv[j]));
        }
        items.add(Positioned(
          left: x(n) + 6,
          top: y(top + 1) - 1.5,
          width: math.max(qTotal, dl) * cw + 12,
          height: 3,
          child: Container(color: C.ink),
        ));
    }

    for (var k = 0; k < qn; k++) {
      final s = plan.steps[k];
      // quotient digit
      switch (layout) {
        case 'pl' || 'en':
          field('q$k', s.pos, 0);
        case 'de':
          field('q$k', n + 2 + dl + s.pos - plan.firstPos, top);
        default:
          field('q$k', n + s.pos - plan.firstPos, top + 1, dx: 12);
      }
      final pRow = base + 2 * k;
      final rRow = pRow + 1;
      final pLen = plan.fieldLen['p$k'] ?? 1;
      final curLen = _len(s.cur);
      items.add(text(x(s.pos - pLen), pRow, '−', color: C.pink, size: 28));
      field('p$k', s.pos, pRow);
      items.add(hLine(s.pos - curLen + 1, s.pos + 1, rRow, thick: 2.5));
      field('r$k', s.pos, rRow);
      if (k + 1 < qn) {
        // the next digit, brought down
        items.add(text(x(s.pos + 1), rRow, '${plan.digits[s.pos + 1]}', color: C.purple));
      }
    }

    final width = x(rightCols) + (layout == 'pot' ? 20 : 4);
    final height = y(rows) + (layout == 'pot' ? 6 : 0);
    return SizedBox(width: width, height: height, child: Stack(clipBehavior: Clip.none, children: items));
  }
}
