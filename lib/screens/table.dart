import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../state.dart';
import '../ui.dart';
import 'exercise.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});
  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  bool _game = false;
  int? _r;
  int? _c;
  String _val = '';
  String? _flash;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _game = app.tableGame(app.me.id) != null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _key(int r, int c) => '$r-$c';

  void _startGame(AppState app, bool random20) {
    final marks = <String, String>{};
    if (random20) {
      final all = <String>[for (var r = 1; r <= 10; r++) for (var c = 1; c <= 10; c++) _key(r, c)]..shuffle(Random());
      for (final k in all.take(20)) {
        marks[k] = 'h';
      }
    } else {
      for (var r = 1; r <= 10; r++) {
        for (var c = 1; c <= 10; c++) {
          marks[_key(r, c)] = 'h';
        }
      }
    }
    app.saveTableGame(app.me.id, TableGame(marks: marks, firstBad: [], start: app.now));
    setState(() {
      _r = null;
      _c = null;
      _val = '';
    });
  }

  void _answer(AppState app, TableGame g) {
    final r = _r, c = _c;
    if (r == null || c == null || _val.isEmpty || _flash != null) return;
    final k = _key(r, c);
    final ok = int.tryParse(_val) == r * c;
    final marks = Map<String, String>.from(g.marks);
    final firstBad = List<String>.from(g.firstBad);
    final wasHidden = marks[k] == 'h';
    marks[k] = ok ? 'ok' : 'bad';
    if (!ok && wasHidden && !firstBad.contains(k)) firstBad.add(k);
    final ng = TableGame(marks: marks, firstBad: firstBad, start: g.start);
    app.saveTableGame(app.me.id, ng);
    setState(() {
      _flash = ok ? 'ok' : 'bad';
      _val = '';
      _r = null;
      _c = null;
    });
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _flash = null);
      final done = !ng.marks.values.any((v) => v != 'ok');
      if (done) _finish(app, ng);
    });
  }

  void _finish(AppState app, TableGame g) {
    final total = g.marks.length;
    final mistakes = g.firstBad.map((k) {
      final p = k.split('-');
      return Mistake(Task(Op.mul, int.parse(p[0]), int.parse(p[1])), '');
    }).toList();
    final s = Session(
      id: app.newId(),
      profileId: app.me.id,
      kind: 'table',
      date: app.now,
      ms: app.now - g.start,
      total: total,
      correct: total - g.firstBad.length,
      mistakes: mistakes,
      desc: total == 100 ? app.t('table_whole') : app.t('table_random'),
    );
    app.addSession(s, stars: s.correct ~/ 2);
    app.saveTableGame(app.me.id, null);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SummaryScreen(
        session: s,
        retry: mistakes.isEmpty
            ? null
            : () => ExerciseScreen(op: Op.mul, choice: false, tasks: mistakes.map((m) => m.task).toList(), kind: 'mul'),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = app.tableGame(app.me.id);
    final hidden = g == null ? 0 : g.marks.values.where((v) => v == 'h').length;
    final bad = g == null ? 0 : g.marks.values.where((v) => v == 'bad').length;
    final round2 = g != null && hidden == 0;

    String status;
    if (!_game) {
      status = app.t('table_look');
    } else if (g == null) {
      status = '';
    } else if (!round2) {
      status = app.t('table_round1').replaceAll('{n}', '$hidden');
    } else {
      status = app.t('table_round2').replaceAll('{n}', '$bad');
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(title: app.t('table_title_short')),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  _tab(app.t('table_view'), !_game, () => setState(() {
                        _game = false;
                        _r = 7;
                        _c = 8;
                      })),
                  const SizedBox(width: 6),
                  _tab(app.t('table_game'), _game, () => setState(() {
                        _game = true;
                        _r = null;
                        _c = null;
                      })),
                ]),
              ),
              const SizedBox(height: 10),
              if (_game && g == null)
                Expanded(child: _gameStart(app))
              else ...[
                LayoutBuilder(builder: (context, cons) => _grid(app, g, round2, cons.maxWidth)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(status, style: ts(15, color: C.inkSoft, weight: FontWeight.w800))),
                  if (_game && g != null)
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(app.t('pause_save'), style: ts(14, color: C.blue)),
                    ),
                ]),
                const Spacer(),
                if (_game && g != null) ...[
                  _questionBar(app),
                  const SizedBox(height: 10),
                  Keypad(
                    wide: true,
                    keyHeight: 56,
                    okEnabled: _val.isNotEmpty && _r != null,
                    onDigit: (d) {
                      if (_r == null || _flash != null) return;
                      setState(() {
                        if (_val.length < 3) _val += d;
                      });
                    },
                    onDelete: () {
                      if (_val.isEmpty) return;
                      setState(() => _val = _val.substring(0, _val.length - 1));
                    },
                    onOk: () => _answer(app, g),
                  ),
                ] else
                  _viewFact(app),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: on ? const [BoxShadow(color: Color(0xFFE2D2B4), offset: Offset(0, 3))] : null,
            ),
            child: Text(label, style: ts(16, color: on ? C.ink : C.inkSoft)),
          ),
        ),
      );

  Widget _gameStart(AppState app) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(app.t('table_game_title'), style: ts(24), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(app.t('table_game_sub'), style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.35), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Chunky(
          height: 72,
          color: C.yellow,
          shadow: C.yellowD,
          radius: 22,
          depth: 6,
          onTap: () => _startGame(app, false),
          child: Text(app.t('table_whole'), style: ts(21)),
        ),
        const SizedBox(height: 10),
        Chunky(
          height: 72,
          radius: 22,
          border: C.line,
          onTap: () => _startGame(app, true),
          child: Text(app.t('table_random'), style: ts(21)),
        ),
      ],
    );
  }

  Widget _grid(AppState app, TableGame? g, bool round2, double width) {
    const gap = 2.0;
    final cell = (width - gap * 10) / 11;
    final rows = <Widget>[];
    for (var r = 0; r <= 10; r++) {
      final cells = <Widget>[];
      for (var c = 0; c <= 10; c++) {
        if (c > 0) cells.add(const SizedBox(width: gap));
        cells.add(_cell(app, g, round2, r, c, cell));
      }
      if (r > 0) rows.add(const SizedBox(height: gap));
      rows.add(Row(children: cells));
    }
    return Column(children: rows);
  }

  Widget _cell(AppState app, TableGame? g, bool round2, int r, int c, double size) {
    Color bg = Colors.white;
    Color fg = C.ink;
    Color? border;
    String label;
    VoidCallback? tap;
    final selected = _r == r && _c == c;
    final inLine = (_r != null && _r == r) || (_c != null && _c == c);

    if (r == 0 && c == 0) {
      bg = C.ink;
      fg = C.yellow;
      label = app.sign(Op.mul);
    } else if (r == 0 || c == 0) {
      final n = r == 0 ? c : r;
      label = '$n';
      final hl = (r == 0 && _c == c) || (c == 0 && _r == r);
      bg = hl ? C.orange : C.yellow;
      fg = hl ? Colors.white : C.ink;
    } else {
      label = '${r * c}';
      final mark = (_game && g != null) ? g.marks[_key(r, c)] : null;
      if (!_game) {
        if (selected) {
          bg = C.orange;
          fg = Colors.white;
        } else if (inLine) {
          bg = const Color(0xFFFFE3CC);
        }
        tap = () => setState(() {
              _r = r;
              _c = c;
            });
      } else if (selected) {
        bg = const Color(0xFFFFF1E6);
        fg = C.orange;
        border = C.orange;
        label = _val.isEmpty ? '?' : _val;
      } else if (mark == 'h') {
        bg = const Color(0xFFEDE3D0);
        fg = const Color(0xFF6B5B3C);
        label = '?';
        if (!round2) tap = () => _select(r, c);
      } else if (mark == 'ok') {
        fg = C.greenD;
        border = C.green;
      } else if (mark == 'bad') {
        bg = C.redBg;
        fg = C.red;
        label = '✗';
        if (round2) {
          border = C.red;
          tap = () => _select(r, c);
        }
      }
    }
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.22),
          border: border == null ? null : Border.all(color: border, width: 2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(label, style: ts(size * 0.42, color: fg)),
          ),
        ),
      ),
    );
  }

  void _select(int r, int c) {
    if (_flash != null) return;
    setState(() {
      _r = r;
      _c = c;
      _val = '';
    });
  }

  Widget _questionBar(AppState app) {
    final has = _r != null && _c != null;
    return Stack(children: [
      Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.sand, width: 2)),
        child: has
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$_r ${app.sign(Op.mul)} $_c = ', style: ts(32)),
                Container(
                  constraints: const BoxConstraints(minWidth: 70),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.orange, width: 3),
                  ),
                  child: Text(_val.isEmpty ? '?' : _val,
                      textScaler: TextScaler.noScaling,
                      style: ts(30, color: C.orange, height: 1.0).copyWith(leadingDistribution: TextLeadingDistribution.even)),
                ),
              ])
            : Text(app.t('table_pick'), style: ts(17, color: C.inkSoft, weight: FontWeight.w800)),
      ),
      if (_flash != null)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(color: _flash == 'ok' ? C.green : C.red, borderRadius: BorderRadius.circular(20)),
            child: Icon(_flash == 'ok' ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 44),
          ),
        ),
    ]);
  }

  Widget _viewFact(AppState app) {
    final r = _r ?? 7, c = _c ?? 8;
    return CardBox(
      child: Column(children: [
        Text('$r ${app.sign(Op.mul)} $c = ${r * c}', style: ts(34)),
        const SizedBox(height: 4),
        Text(app.t('table_tap_hint'), style: ts(14, color: C.inkSoft, weight: FontWeight.w700), textAlign: TextAlign.center),
      ]),
    );
  }
}
