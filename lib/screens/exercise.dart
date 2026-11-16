import 'dart:async';

import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../ui.dart';
import 'home.dart';

String kindLabel(AppState app, String kind) {
  switch (kind) {
    case 'add':
    case 'sub':
    case 'mul':
    case 'div':
      return app.opName(opFromName(kind));
    case 'table':
      return app.t('table_title_short');
    case 'column':
      return app.t('column_title');
    case 'quiz0':
      return '${app.t('quiz')} ${app.sign(Op.add)} ${app.sign(Op.sub)}';
    case 'quiz1':
      return '${app.t('quiz')} ${app.sign(Op.mul)} ${app.sign(Op.div)}';
  }
  return kind;
}

String moduleDesc(AppState app, Op op) {
  final m = app.module(op);
  if (op == Op.mul || op == Op.div) {
    final nums = List<int>.from(m.numbers)..sort();
    String numsText;
    if (nums.isEmpty) {
      numsText = '2–9';
    } else {
      var contiguous = true;
      for (var i = 1; i < nums.length; i++) {
        if (nums[i] != nums[i - 1] + 1) contiguous = false;
      }
      numsText = contiguous && nums.length > 2 ? '${nums.first}–${nums.last}' : nums.join(', ');
    }
    return '${app.t('numbers')} $numsText · ${m.count} ${app.t('tasks_word')}';
  }
  final r = AppState.ranges[m.range];
  return '${app.t('up_to')} $r · ${m.count} ${app.t('tasks_word')}';
}

class ModePickScreen extends StatelessWidget {
  final Op op;
  const ModePickScreen({super.key, required this.op});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget card({required Color c, required Color d, required Widget art, required String title, required String sub, required bool choice}) {
      return Chunky(
        color: Colors.white,
        border: c,
        borderWidth: 3,
        shadow: d,
        radius: 28,
        depth: 7,
        padding: const EdgeInsets.all(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseScreen(op: op, choice: choice))),
        child: Row(children: [
          SizedBox(width: 104, child: art),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(23, height: 1.1)),
              const SizedBox(height: 6),
              Text(sub, style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.3)),
            ]),
          ),
        ]),
      );
    }

    Widget miniKey(String s, {Color bg = C.paper, Color fg = C.ink}) => Container(
          height: 28,
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(s, style: ts(14, color: fg)),
        );
    final keypadArt = Column(children: [
      Row(children: [Expanded(child: miniKey('1')), Expanded(child: miniKey('2')), Expanded(child: miniKey('3'))]),
      Row(children: [Expanded(child: miniKey('4')), Expanded(child: miniKey('5')), Expanded(child: miniKey('6'))]),
      Row(children: [
        Expanded(child: miniKey('⌫')),
        Expanded(child: miniKey('0')),
        Expanded(child: miniKey('OK', bg: C.green, fg: Colors.white)),
      ]),
    ]);
    Widget opt(String s, bool good) => Container(
          height: 42,
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: good ? C.green : const Color(0xFFEAF1FE), borderRadius: BorderRadius.circular(12)),
          child: Text(s, style: ts(19, color: good ? Colors.white : C.ink)),
        );
    final choiceArt = Column(children: [
      Row(children: [Expanded(child: opt('48', false)), Expanded(child: opt('56', true))]),
      Row(children: [Expanded(child: opt('54', false)), Expanded(child: opt('63', false))]),
    ]);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(title: app.opName(op), badge: OpBadge(op: op)),
              const SizedBox(height: 24),
              Text(app.t('how_answer'), style: ts(24), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              card(c: C.orange, d: C.orangeD, art: keypadArt, title: app.t('mode_type'), sub: app.t('mode_type_sub'), choice: false),
              const SizedBox(height: 14),
              card(c: C.blue, d: C.blueD, art: choiceArt, title: app.t('mode_choice'), sub: app.t('mode_choice_sub'), choice: true),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: C.paper, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Icon(Icons.tune_rounded, color: C.inkSoft, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(moduleDesc(app, op), style: ts(14, color: C.inkSoft, weight: FontWeight.w800))),
                  TextButton(
                    onPressed: () => openSettings(context),
                    child: Text(app.t('change'), style: ts(14, color: C.blue).copyWith(decoration: TextDecoration.underline)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exercise with keypad (choice == false) or 4 answer options (choice == true).
class ExerciseScreen extends StatefulWidget {
  final Op? op;
  final bool choice;
  final List<Task>? tasks;
  final String? kind;
  const ExerciseScreen({super.key, this.op, required this.choice, this.tasks, this.kind});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late List<Task> _tasks;
  int _idx = 0;
  String _val = '';
  String? _flash; // ok / bad
  int? _picked;
  List<int> _opts = [];
  final List<Mistake> _mistakes = [];
  int _good = 0;
  late int _start;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    if (widget.tasks != null && widget.tasks!.isNotEmpty) {
      _tasks = List.of(widget.tasks!);
    } else {
      final op = widget.op ?? Op.mul;
      _tasks = Gen.exercise(op, app.module(op), app.module(op).count);
    }
    _start = DateTime.now().millisecondsSinceEpoch;
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Task get _task => _tasks[_idx];

  Op get _op => widget.op ?? _task.op;

  void _prepare() {
    _val = '';
    _picked = null;
    _opts = widget.choice ? Gen.options(_task) : [];
  }

  void _answer(String given) {
    if (_flash != null) return;
    final ok = int.tryParse(given) == _task.answer;
    setState(() {
      _flash = ok ? 'ok' : 'bad';
      if (ok) {
        _good++;
      } else {
        _mistakes.add(Mistake(_task, given));
      }
    });
    _timer = Timer(Duration(milliseconds: ok ? 600 : 1300), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_idx + 1 >= _tasks.length) {
      _finish();
      return;
    }
    setState(() {
      _idx++;
      _flash = null;
      _prepare();
    });
  }

  void _finish() {
    final app = AppScope.read(context);
    final ms = DateTime.now().millisecondsSinceEpoch - _start;
    final kind = widget.kind ?? (widget.op?.name ?? _task.op.name);
    final desc = widget.tasks != null
        ? app.t('retry_desc')
        : '${moduleDesc(app, _op)} · ${widget.choice ? app.t('mode_choice_short') : app.t('mode_type_short')}';
    final s = Session(
      id: app.newId(),
      profileId: app.me.id,
      kind: kind,
      date: app.now,
      ms: ms,
      total: _tasks.length,
      correct: _good,
      mistakes: List.of(_mistakes),
      desc: desc,
      choice: widget.choice,
      stars: starsFor(_good, _tasks.length),
    );
    app.addSession(s);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SummaryScreen(
        session: s,
        retry: s.mistakes.isEmpty
            ? null
            : () => ExerciseScreen(
                  op: widget.op,
                  choice: widget.choice,
                  tasks: s.mistakes.map((m) => m.task).toList(),
                  kind: kind,
                ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final color = C.op(_op);
    final left = _tasks.length - _idx - (_flash != null ? 1 : 0);
    final progress = _tasks.isEmpty ? 0.0 : (_idx + (_flash != null ? 1 : 0)) / _tasks.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52,
                child: Row(children: [
                  IconBox(icon: Icons.close_rounded, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: LinearProgressIndicator(value: progress, minHeight: 14, color: color, backgroundColor: C.sand),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(14)),
                    child: Text('${app.t('left')} $left', style: ts(15, color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: C.sand, width: 2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_task.missing ? app.t('which_number') : app.t('how_much'),
                            style: ts(16, color: C.inkSoft, weight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        TaskLine(task: _task, typed: widget.choice ? '?' : _val, boxColor: color, signColor: color),
                      ]),
                    ),
                  ),
                  if (_flash != null)
                    FeedbackOverlay(ok: _flash == 'ok', text: _flash == 'ok' ? app.t('good') : app.fullText(_task)),
                ]),
              ),
              const SizedBox(height: 16),
              if (widget.choice)
                Column(children: [
                  Gap(gap: 14, children: [_optBtn(0), _optBtn(1)]),
                  const SizedBox(height: 8),
                  Gap(gap: 14, children: [_optBtn(2), _optBtn(3)]),
                ])
              else
                Keypad(
                  keyHeight: 64,
                  okEnabled: _val.isNotEmpty && _flash == null,
                  onDigit: (d) {
                    if (_flash != null) return;
                    setState(() {
                      if (_val.length < 4) _val += d;
                    });
                  },
                  onDelete: () {
                    if (_flash != null || _val.isEmpty) return;
                    setState(() => _val = _val.substring(0, _val.length - 1));
                  },
                  onOk: () {
                    if (_val.isNotEmpty) _answer(_val);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optBtn(int i) {
    if (i >= _opts.length) return const SizedBox.shrink();
    final v = _opts[i];
    var bg = Colors.white;
    var fg = C.ink;
    var border = C.line;
    var shadow = C.line;
    if (_flash != null && v == _task.answer) {
      bg = C.green;
      fg = Colors.white;
      border = C.green;
      shadow = C.greenD;
    } else if (_flash != null && v == _picked) {
      bg = C.redBg;
      fg = C.red;
      border = C.red;
      shadow = const Color(0xFFE8B4B4);
    }
    return Chunky(
      height: 104,
      radius: 26,
      depth: 6,
      color: bg,
      border: border,
      borderWidth: 3,
      shadow: shadow,
      onTap: () {
        if (_flash != null) return;
        _picked = v;
        _answer('$v');
      },
      child: FittedBox(fit: BoxFit.scaleDown, child: Text('$v', textScaler: TextScaler.noScaling, style: tsBox(46, color: fg))),
    );
  }
}

class SummaryScreen extends StatelessWidget {
  final Session session;
  final Widget Function()? retry;
  const SummaryScreen({super.key, required this.session, this.retry});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = session;
    final stars = starsFor(s.correct, s.total);
    final title = stars == 3 ? app.t('great') : (stars == 2 ? app.t('good_job') : app.t('keep_going'));
    Widget stat(String big, String small, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.sand, width: 2)),
            child: Column(children: [
              FittedBox(child: Text(big, style: ts(26, color: c))),
              Text(small, style: ts(13, color: C.inkSoft, weight: FontWeight.w800), textAlign: TextAlign.center),
            ]),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(Icons.star_rounded, size: i == 1 ? 84 : 62, color: i < stars ? C.yellow : C.sand),
                ],
              ),
              Text(title, style: ts(30), textAlign: TextAlign.center),
              Text(kindLabel(app, s.kind), style: ts(16, color: C.inkSoft, weight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(children: [
                stat('${s.correct}/${s.total}', app.t('correct_first'), C.greenD),
                const SizedBox(width: 10),
                stat(fmtMs(s.ms).split(',').first, app.t('time'), C.ink),
                const SizedBox(width: 10),
                stat('+${s.stars}', app.t('stars'), const Color(0xFFB07800)),
              ]),
              const SizedBox(height: 16),
              if (s.mistakes.isNotEmpty)
                Expanded(
                  child: CardBox(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app.t('to_repeat'), style: ts(17)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final m in s.mistakes)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(14)),
                                child: Text(app.fullText(m.task), style: ts(19, color: const Color(0xFFA61E1E))),
                              ),
                          ]),
                        ),
                      ),
                      Text(app.t('repeat_note'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
                    ]),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(height: 16),
              if (retry != null) ...[
                Chunky(
                  height: 62,
                  color: C.orange,
                  shadow: C.orangeD,
                  radius: 22,
                  depth: 6,
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => retry!())),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.replay_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(app.t('fix_mistakes'), style: ts(20, color: Colors.white)),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              Chunky(
                height: 58,
                radius: 22,
                border: C.line,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(app.t('back_menu'), style: ts(19)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
