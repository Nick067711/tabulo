import 'dart:async';

import 'package:flutter/material.dart';

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

/// Values of the small boxes above the columns: +1 carried when adding, −1 borrowed when subtracting.
const markPlus = '+1';
const markMinus = '−1';

/// Expected values for written addition, subtraction and multiplication by a one-digit number.
class ColumnPlan {
  final Task task;
  final int width;
  final Map<String, String> expected; // c1..cN carry/borrow marks, r0..rN result digits
  final List<String> order; // order of cells for the "next" button
  ColumnPlan._(this.task, this.width, this.expected, this.order);

  factory ColumnPlan(Task t) {
    final res = t.result;
    final w = [t.a, t.b, res].map((v) => '$v'.length).reduce((a, b) => a > b ? a : b);
    final exp = <String, String>{};
    var carry = 0;
    for (var i = 0; i < w; i++) {
      if (i > 0) {
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
      if (i + 1 < w) order.add('c${i + 1}');
    }
    return ColumnPlan._(t, w, exp, order);
  }

  bool isRight(String cell, String value) {
    final e = expected[cell] ?? '';
    if (e.isEmpty) return value.isEmpty || value == '0';
    return value == e;
  }
}

/// One step of long division: how many times the divisor fits into [cur].
class DivStep {
  final int pos; // index (from the left) of the last dividend digit used in this step
  final int cur, q, prod, rem;
  const DivStep(this.pos, this.cur, this.q, this.prod, this.rem);
}

/// Expected values for long division by a one-digit number.
/// Fields: q{k} quotient digit, p{k} product, r{k} remainder of step k.
class DivPlan {
  final Task task;
  final List<int> digits;
  final List<DivStep> steps;
  final Map<String, String> expected;
  final Map<String, int> maxLen;
  final List<String> order;
  DivPlan._(this.task, this.digits, this.steps, this.expected, this.maxLen, this.order);

  factory DivPlan(Task t) {
    final ds = '${t.a}'.split('').map(int.parse).toList();
    final d = t.b;
    var pos = 0;
    var cur = ds[0];
    while (cur < d && pos < ds.length - 1) {
      pos++;
      cur = cur * 10 + ds[pos];
    }
    final steps = <DivStep>[];
    while (true) {
      final q = cur ~/ d;
      final p = q * d;
      final r = cur - p;
      steps.add(DivStep(pos, cur, q, p, r));
      if (pos + 1 >= ds.length) break;
      pos++;
      cur = r * 10 + ds[pos];
    }
    final exp = <String, String>{};
    final len = <String, int>{};
    final order = <String>[];
    for (var k = 0; k < steps.length; k++) {
      final s = steps[k];
      final last = k == steps.length - 1;
      exp['q$k'] = '${s.q}';
      len['q$k'] = 1;
      exp['p$k'] = '${s.prod}';
      len['p$k'] = '${s.prod}'.length;
      // An intermediate remainder of 0 may be left empty.
      exp['r$k'] = !last && s.rem == 0 ? '' : '${s.rem}';
      len['r$k'] = '${s.rem}'.length;
      order.addAll(['q$k', 'p$k', 'r$k']);
    }
    return DivPlan._(t, ds, steps, exp, len, order);
  }

  bool isRight(String id, String value) {
    final e = expected[id] ?? '';
    if (e.isEmpty) return value.isEmpty || value == '0';
    return value == e;
  }

  /// The field is filled in as far as the expected answer goes.
  bool isFull(String id, String value) {
    final e = expected[id] ?? '';
    return e.isEmpty ? value.isNotEmpty : value.length >= e.length;
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
  bool _started = false;
  List<Task> _tasks = [];
  int _idx = 0;
  ColumnPlan? _plan;
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
  bool get _isDiv => _task.op == Op.div;
  List<String> get _order => _isDiv ? _div!.order : _plan!.order;
  Map<String, String> get _expected => _isDiv ? _div!.expected : _plan!.expected;
  bool _right(String id, String v) => _isDiv ? _div!.isRight(id, v) : _plan!.isRight(id, v);

  void _begin(List<Task> tasks) {
    _tasks = tasks;
    _idx = 0;
    _started = true;
    _start = DateTime.now().millisecondsSinceEpoch;
    _load();
  }

  void _load() {
    if (_task.op == Op.div) {
      _div = DivPlan(_task);
      _plan = null;
      _sel = 'q0';
    } else {
      _plan = ColumnPlan(_task);
      _div = null;
      _sel = 'r0';
    }
    _vals.clear();
    _checked = false;
    _failedThis = false;
    _solved = false;
  }

  /// The +1 / −1 buttons are for addition and subtraction only.
  bool get _usesMarkBar => _task.op == Op.add || _task.op == Op.sub;
  bool get _onMark => (_sel ?? '').startsWith('c');

  /// Digit from the keypad.
  void _type(String d) {
    final s = _sel;
    if (s == null || _solved) return;
    if (_isDiv) {
      _typeDiv(s, d);
      return;
    }
    final plan = _plan!;
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
      final noMark = (plan.expected['c${col + 1}'] ?? '').isEmpty;
      // Nothing to carry or borrow and the digit is right: go straight to the next result box.
      _sel = noMark && plan.isRight(s, d) ? 'r${col + 1}' : 'c${col + 1}';
    });
  }

  void _typeDiv(String s, String d) {
    final plan = _div!;
    final max = plan.maxLen[s] ?? 1;
    var v = _vals[s] ?? '';
    v = v.length >= max ? d : v + d;
    setState(() {
      _vals[s] = v;
      _checked = false;
      if (plan.isFull(s, v)) {
        final i = plan.order.indexOf(s);
        if (i >= 0 && i + 1 < plan.order.length) _sel = plan.order[i + 1];
      }
    });
  }

  void _delete() {
    final s = _sel;
    if (s == null || _solved) return;
    if (!_isDiv && s.startsWith('c') && _usesMarkBar) return;
    setState(() {
      final v = _vals[s] ?? '';
      if (_isDiv && v.length > 1) {
        _vals[s] = v.substring(0, v.length - 1);
      } else {
        _vals.remove(s);
      }
      _checked = false;
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
    if (all) {
      // Wait for "Next"; after 5 seconds the next task opens by itself.
      _nextIn = 5;
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
      desc: widget.tasks != null
          ? app.t('retry_desc')
          : '${app.opName(_op)} · ${app.t('digits_n').replaceAll('{n}', '$_digits')}',
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

  String _hint(AppState app) {
    if (_isDiv) return _divHint(app);
    final plan = _plan!;
    final t = plan.task;
    final m = app.sign(Op.mul);
    final sel = _sel ?? 'r0';
    if (sel.startsWith('c')) {
      return app.t(switch (t.op) {
        Op.add => 'hint_mark_add',
        Op.sub => 'hint_mark_sub',
        _ => 'hint_mark_mul',
      });
    }
    final col = int.tryParse(sel.substring(1)) ?? 0;
    final da = _dig(t.a, col), db = _dig(t.b, col);
    final markText = col > 0 ? (plan.expected['c$col'] ?? '') : '';
    if (t.op == Op.mul) {
      final carryIn = int.tryParse(markText) ?? 0;
      if (t.a < _pow10(col)) {
        return app.t('hint_mul_last').replaceAll('{c}', '$carryIn');
      }
      final v = da * t.b + carryIn;
      final e = carryIn > 0 ? '$da $m ${t.b} = ${da * t.b}, ${da * t.b} + $carryIn = $v' : '$da $m ${t.b} = $v';
      if (v >= 10 && col + 1 < plan.width) {
        return app.t('hint_mul_carry').replaceAll('{e}', e).replaceAll('{d}', '${v % 10}').replaceAll('{c}', '${v ~/ 10}');
      }
      return app.t('hint_mul').replaceAll('{e}', e);
    }
    final mark = markText.isEmpty ? 0 : 1;
    if (t.op == Op.add) {
      final s = da + db + mark;
      final plus = mark == 1 ? ' + 1' : '';
      if (s >= 10) {
        return app.t('hint_add_carry').replaceAll('{e}', '$da + $db$plus = $s').replaceAll('{d}', '${s % 10}');
      }
      return app.t('hint_add').replaceAll('{e}', '$da + $db$plus = $s');
    }
    final top = da - mark;
    if (top < db) {
      return app.t('hint_sub_borrow').replaceAll('{e}', '${top + 10} − $db = ${top + 10 - db}');
    }
    return app.t('hint_sub').replaceAll('{e}', '$top − $db = ${top - db}');
  }

  String _divHint(AppState app) {
    final plan = _div!;
    final sel = _sel ?? 'q0';
    final k = int.tryParse(sel.substring(1)) ?? 0;
    final s = plan.steps[k.clamp(0, plan.steps.length - 1)];
    final d = plan.task.b;
    if (sel.startsWith('q')) {
      return app.t('hint_div_q').replaceAll('{d}', '$d').replaceAll('{n}', '${s.cur}');
    }
    if (sel.startsWith('p')) {
      return app.t('hint_div_p').replaceAll('{e}', '${s.q} ${app.sign(Op.mul)} $d').replaceAll('{n}', '${s.cur}');
    }
    final last = k == plan.steps.length - 1;
    return app.t(last ? 'hint_div_last' : 'hint_div_r').replaceAll('{e}', '${s.cur} − ${s.prod}');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!_started) return _setup(app);
    return Scaffold(
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
                  child: FittedBox(fit: BoxFit.scaleDown, child: _isDiv ? _divBoard(app) : _board(app)),
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
                        Text('${app.t('next')}  ›  ($_nextIn)', style: ts(20, color: Colors.white)),
                      ])
                    : Text(_checked ? '✗ ${app.t('fix_red')}' : 'OK', style: ts(20, color: Colors.white)),
              ),
            ],
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
      Op.mul => app.t('column_info_mul'),
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
                        Pick(
                          label: app.t('digits_n').replaceAll('{n}', '$d'),
                          on: _digits == d,
                          color: C.pink,
                          dark: C.pinkD,
                          height: 56,
                          fontSize: 16,
                          onTap: () => setState(() => _digits = d),
                        ),
                    ]),
                    if (_op == Op.mul || _op == Op.div)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(app.t('one_digit_note'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 16),
                    CardBox(
                      child: Text(info, style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.4)),
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
                onTap: () => setState(() => _begin(Gen.column(_op, _digits, 5))),
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

  // ---------------- + − × board ----------------

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
          SizedBox(height: 44, child: Center(child: i > 0 ? cellBox('c$i', small: true) : null)),
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

  // ---------------- long division board ----------------

  /// Layouts (Settings › General): pl – result above the line over the dividend, ": d" beside it;
  /// en – divisor and bracket on the left, result above; de – "a : d = result" in one line;
  /// pot – divisor on the right in a corner, result under it (France, Spain, Ukraine).
  Widget _divBoard(AppState app) {
    final plan = _div!;
    final layout = app.divLayout;
    final n = plan.digits.length;
    final qn = plan.steps.length;
    const cw = 44.0;
    const rh = 46.0;
    final left = layout == 'en' ? 3 : 1; // columns kept free on the left (minus signs, divisor)
    final top = layout == 'pl' || layout == 'en' ? 1 : 0; // row of the dividend
    final base = top + 1; // first row of the steps
    final rightCols = switch (layout) {
      'pl' => n + 2,
      'de' => n + 3 + qn,
      'pot' => n + qn + 1,
      _ => n,
    };
    final rows = base + 2 * qn;
    double x(num col) => (col + left) * cw;
    double y(num row) => row * rh;
    final items = <Widget>[];

    Widget text(num col, num row, String s, {Color color = C.ink, double size = 32}) => Positioned(
          left: x(col),
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

    void field(String id, int endCol, num row) {
      final len = plan.maxLen[id] ?? 1;
      final v = _vals[id] ?? '';
      final sel = _sel == id;
      final look = _look(id, v);
      final start = endCol - len + 1;
      for (var c = start; c <= endCol; c++) {
        final idx = v.length - (endCol - c) - 1;
        final ch = idx >= 0 && idx < v.length ? v[idx] : '';
        items.add(Positioned(
          left: x(c) + 2,
          top: y(row) + 3,
          width: cw - 4,
          height: rh - 6,
          child: GestureDetector(
            onTap: () => setState(() => _sel = id),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: look.dashed && !sel ? Colors.transparent : look.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: look.border, width: sel || _checked ? 3 : 2),
              ),
              child: Text(ch, textScaler: TextScaler.noScaling, style: tsBox(28, color: look.fg)),
            ),
          ),
        ));
      }
    }

    // dividend
    for (var i = 0; i < n; i++) {
      items.add(text(i, top, '${plan.digits[i]}'));
    }
    final dv = '${plan.task.b}';
    final divSign = app.sign(Op.div);
    switch (layout) {
      case 'pl':
        items.add(text(n, top, divSign, color: C.pink));
        items.add(text(n + 1, top, dv));
        items.add(hLine(0, n, top));
      case 'en':
        items.add(text(-2, top, dv));
        items.add(text(-1, top, ')', size: 40));
        items.add(hLine(0, n, top));
      case 'de':
        items.add(text(n, top, divSign, color: C.pink));
        items.add(text(n + 1, top, dv));
        items.add(text(n + 2, top, '=', color: C.pink));
      default: // pot
        items.add(Positioned(
          left: x(n) + 6,
          top: y(top) + 4,
          width: 3,
          height: rh * 2 - 8,
          child: Container(color: C.ink),
        ));
        items.add(Positioned(
          left: x(n) + 12,
          top: y(top),
          width: cw,
          height: rh,
          child: Center(child: Text(dv, textScaler: TextScaler.noScaling, style: tsBox(32))),
        ));
        items.add(Positioned(
          left: x(n) + 6,
          top: y(top + 1) - 1.5,
          width: qn * cw + 12,
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
          field('q$k', n + 3 + k, top);
        default:
          // under the divisor, a little to the right of the corner line
          final v = _vals['q$k'] ?? '';
          final look = _look('q$k', v);
          final sel = _sel == 'q$k';
          items.add(Positioned(
            left: x(n + k) + 14,
            top: y(top + 1) + 5,
            width: cw - 4,
            height: rh - 6,
            child: GestureDetector(
              onTap: () => setState(() => _sel = 'q$k'),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.dashed && !sel ? Colors.transparent : look.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: look.border, width: sel || _checked ? 3 : 2),
                ),
                child: Text(v, textScaler: TextScaler.noScaling, style: tsBox(28, color: look.fg)),
              ),
            ),
          ));
      }
      final pRow = base + 2 * k;
      final rRow = pRow + 1;
      final pLen = plan.maxLen['p$k'] ?? 1;
      final curLen = '${s.cur}'.length;
      items.add(text(s.pos - pLen, pRow, '−', color: C.pink, size: 28));
      field('p$k', s.pos, pRow);
      items.add(hLine(s.pos - curLen + 1, s.pos + 1, rRow, thick: 2.5));
      field('r$k', s.pos, rRow);
      if (k + 1 < qn) {
        // the next digit, brought down
        items.add(text(s.pos + 1, rRow, '${plan.digits[s.pos + 1]}', color: C.purple));
      }
    }

    final width = x(rightCols) + (layout == 'pot' ? 20 : 4);
    final height = y(rows) + (layout == 'pot' ? 6 : 0);
    return SizedBox(width: width, height: height, child: Stack(clipBehavior: Clip.none, children: items));
  }
}
