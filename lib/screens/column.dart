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

/// Expected values for one written (column) operation.
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
      if (i > 0) exp['c$i'] = carry == 1 ? '1' : '';
      final da = _dig(t.a, i), db = _dig(t.b, i);
      if (t.op == Op.add) {
        carry = da + db + carry >= 10 ? 1 : 0;
      } else {
        carry = da - carry < db ? 1 : 0;
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
  late ColumnPlan _plan;
  final Map<String, String> _vals = {};
  String? _sel;
  bool _checked = false;
  bool _failedThis = false;
  bool _solved = false;
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

  void _begin(List<Task> tasks) {
    _tasks = tasks;
    _idx = 0;
    _started = true;
    _start = DateTime.now().millisecondsSinceEpoch;
    _load();
  }

  void _load() {
    _plan = ColumnPlan(_tasks[_idx]);
    _vals.clear();
    _sel = 'r0';
    _checked = false;
    _failedThis = false;
    _solved = false;
  }

  void _type(String d) {
    final s = _sel;
    if (s == null || _solved) return;
    setState(() {
      _vals[s] = d;
      _checked = false;
      final i = _plan.order.indexOf(s);
      if (i >= 0 && i + 1 < _plan.order.length) _sel = _plan.order[i + 1];
    });
  }

  void _check() {
    if (_solved) return;
    var all = true;
    for (final k in _plan.expected.keys) {
      if (!_plan.isRight(k, _vals[k] ?? '')) all = false;
    }
    setState(() {
      _checked = true;
      if (all) {
        _solved = true;
        if (!_failedThis) _good++;
      } else {
        if (!_failedThis) {
          _failedThis = true;
          _mistakes.add(Mistake(_plan.task, ''));
        }
      }
    });
    if (all) {
      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        if (_idx + 1 >= _tasks.length) {
          _finish();
        } else {
          setState(() {
            _idx++;
            _load();
          });
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
          : '${_op == Op.add ? app.opName(Op.add) : app.opName(Op.sub)} · ${app.t('digits_n').replaceAll('{n}', '$_digits')}',
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
    final sel = _sel ?? 'r0';
    final col = int.tryParse(sel.substring(1)) ?? 0;
    final t = _plan.task;
    final da = _dig(t.a, col), db = _dig(t.b, col);
    final mark = col > 0 && (_plan.expected['c$col'] ?? '') == '1' ? 1 : 0;
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
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _board(app)))),
              const SizedBox(height: 8),
              Keypad(
                wide: true,
                keyHeight: 54,
                onDigit: _type,
                onDelete: () {
                  final s = _sel;
                  if (s == null || _solved) return;
                  setState(() {
                    _vals.remove(s);
                    _checked = false;
                  });
                },
                onOk: _check,
                extraIcon: Icons.arrow_forward_rounded,
                onExtra: () {
                  final s = _sel ?? 'r0';
                  final i = _plan.order.indexOf(s);
                  setState(() => _sel = _plan.order[(i + 1) % _plan.order.length]);
                },
              ),
              const SizedBox(height: 4),
              Chunky(
                height: 58,
                color: _solved ? C.green : C.pink,
                shadow: _solved ? C.greenD : C.pinkD,
                radius: 20,
                depth: 6,
                onTap: _check,
                child: Text(
                  _solved
                      ? '✓ ${app.t('bravo')} ${app.fullText(_plan.task)}'
                      : (_checked ? '✗ ${app.t('fix_red')}' : 'OK'),
                  style: ts(20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _setup(AppState app) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(title: app.t('column_title')),
              const SizedBox(height: 20),
              SectionLabel(app.t('which_op')),
              Gap(children: [
                Pick(label: '${app.sign(Op.add)}  ${app.opName(Op.add)}', on: _op == Op.add, color: C.green, dark: C.greenD, height: 60, onTap: () => setState(() => _op = Op.add)),
                Pick(label: '${app.sign(Op.sub)}  ${app.opName(Op.sub)}', on: _op == Op.sub, color: C.blue, dark: C.blueD, height: 60, onTap: () => setState(() => _op = Op.sub)),
              ]),
              const SizedBox(height: 18),
              SectionLabel(app.t('how_many_digits')),
              Gap(children: [
                for (final d in [2, 3, 4])
                  Pick(label: app.t('digits_n').replaceAll('{n}', '$d'), on: _digits == d, color: C.pink, dark: C.pinkD, height: 56, fontSize: 16, onTap: () => setState(() => _digits = d)),
              ]),
              const SizedBox(height: 18),
              CardBox(
                child: Text(app.t('column_info'), style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.4)),
              ),
              const Spacer(),
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

  Widget _board(AppState app) {
    final t = _plan.task;
    final w = _plan.width;
    const colW = 64.0;
    final sign = app.sign(t.op);

    Widget cellBox(String id, {bool small = false}) {
      final v = _vals[id] ?? '';
      final sel = _sel == id;
      Color border = small ? const Color(0xFFC9B48F) : C.line;
      Color bg = Colors.white;
      Color fg = small ? C.pink : C.ink;
      var dashed = v.isEmpty;
      if (_checked) {
        final ok = _plan.isRight(id, v);
        if (!ok) {
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
      if (sel && !_solved) {
        border = C.pink;
        bg = const Color(0xFFFFF0F5);
        fg = C.pink;
      }
      final size = small ? 38.0 : 56.0;
      return GestureDetector(
        onTap: () => setState(() => _sel = id),
        child: Container(
          width: size,
          height: small ? 38 : 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dashed && !sel ? Colors.transparent : bg,
            borderRadius: BorderRadius.circular(small ? 10 : 16),
            border: Border.all(color: border, width: sel || _checked ? 3 : 2),
          ),
          child: Text(v,
              textScaler: TextScaler.noScaling,
              style: ts(small ? 20 : 38, color: fg, height: 1.0).copyWith(leadingDistribution: TextLeadingDistribution.even)),
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
}
