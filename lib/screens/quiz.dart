import 'dart:async';

import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../ui.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _phase = 'intro'; // intro, count, play, done
  int _group = 1;
  int _count = 3;
  int _idx = 0;
  Task? _q;
  String _val = '';
  int _good = 0;
  int _bad = 0;
  int _startAt = 0;
  int _endAt = 0;
  String? _flash;
  final List<Mistake> _mistakes = [];
  final List<Timer> _timers = [];
  Timer? _tick;
  QuizOutcome? _outcome;
  int _earned = 0;
  int _total = 100;

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }

  void _stopAll() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _tick?.cancel();
    _tick = null;
  }

  void _start(AppState app) {
    _stopAll();
    _total = app.quizCount;
    setState(() {
      _phase = 'count';
      _count = 3;
    });
    _timers.add(Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _count = 2);
    }));
    _timers.add(Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _count = 1);
    }));
    _timers.add(Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _phase = 'play';
        _idx = 0;
        _good = 0;
        _bad = 0;
        _mistakes.clear();
        _val = '';
        _flash = null;
        _q = Gen.quiz(_group, null);
        _startAt = DateTime.now().millisecondsSinceEpoch;
        _endAt = 0;
      });
      _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
    }));
  }

  void _submit(AppState app) {
    final q = _q;
    if (q == null || _val.isEmpty || _flash != null) return;
    final ok = int.tryParse(_val) == q.answer;
    final last = _idx + 1 >= _total;
    setState(() {
      _flash = ok ? 'ok' : 'bad';
      if (ok) {
        _good++;
      } else {
        _bad++;
        _mistakes.add(Mistake(q, _val));
      }
      if (last) _endAt = DateTime.now().millisecondsSinceEpoch;
    });
    if (last) {
      _tick?.cancel();
      _timers.add(Timer(const Duration(milliseconds: 400), () {
        if (mounted) _finish(app);
      }));
    } else {
      _timers.add(Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _idx++;
          _q = Gen.quiz(_group, _q);
          _val = '';
          _flash = null;
        });
      }));
    }
  }

  void _finish(AppState app) {
    final ms = _endAt - _startAt;
    final outcome = app.addQuizResult(_group, _good, ms);
    app.addSession(
      Session(
        id: app.newId(),
        profileId: app.me.id,
        kind: 'quiz$_group',
        date: app.now,
        ms: ms,
        total: _total,
        correct: _good,
        mistakes: List.of(_mistakes),
        desc: '$_total ${app.t('tasks_word')}',
        stars: starsFor(_good, _total) + (outcome.isRecord ? 3 : 0),
      ),
    );
    setState(() {
      _earned = starsFor(_good, _total) + (outcome.isRecord ? 3 : 0);
      _outcome = outcome;
      _phase = 'done';
      _flash = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: C.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(
                title: app.t('quiz'),
                dark: true,
                backIcon: _phase == 'play' ? Icons.close_rounded : Icons.chevron_left_rounded,
                onBack: () {
                  if (_phase == 'play' || _phase == 'count') {
                    _stopAll();
                    setState(() => _phase = 'intro');
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                actions: [Text(app.me.name, style: ts(15, color: C.soft2, weight: FontWeight.w800))],
              ),
              const SizedBox(height: 14),
              Expanded(child: _body(app)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppState app) {
    switch (_phase) {
      case 'count':
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(app.t('get_ready'), style: ts(20, color: C.soft2, weight: FontWeight.w800)),
          const SizedBox(height: 20),
          Container(
            width: 200,
            height: 200,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: C.yellow,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: C.yellowD, offset: Offset(0, 10))],
            ),
            child: Text('$_count', style: ts(120, height: 1)),
          ),
        ]);
      case 'play':
        return _play(app);
      case 'done':
        return _done(app);
    }
    return _intro(app);
  }

  Widget _groupCard(AppState app, int g) {
    final on = _group == g;
    final s1 = g == 0 ? Op.add : Op.mul;
    final s2 = g == 0 ? Op.sub : Op.div;
    final best = app.bestOf(app.me.id, g);
    Widget sq(Op op) => Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.op(op), borderRadius: BorderRadius.circular(14)),
          child: Text(app.sign(op), style: ts(30, color: Colors.white, height: 1)),
        );
    return Chunky(
      height: 156,
      color: on ? C.navy2 : const Color(0xFF262C57),
      shadow: on ? C.yellowD : C.navyD,
      border: on ? C.yellow : C.navy2,
      borderWidth: 3,
      radius: 26,
      depth: 6,
      padding: const EdgeInsets.all(8),
      onTap: () => setState(() => _group = g),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [sq(s1), const SizedBox(width: 6), sq(s2)]),
        const SizedBox(height: 8),
        Text(g == 0 ? app.t('group_as') : app.t('group_md'),
            style: ts(14, color: Colors.white), textAlign: TextAlign.center, maxLines: 2),
        const SizedBox(height: 2),
        Text(
          best == null ? app.t('no_record') : '${app.t('record')}: ${best.correct} ✓ · ${fmtMs(best.ms)}',
          style: ts(12, color: C.soft2, weight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _intro(AppState app) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(app.t('pick_group'), style: ts(18, color: Colors.white)),
      const SizedBox(height: 10),
      Gap(gap: 12, children: [_groupCard(app, 0), _groupCard(app, 1)]),
      const SizedBox(height: 14),
      Expanded(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.navy2, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(app.t('task_count'), style: ts(15, color: C.soft2, weight: FontWeight.w800))),
                Text('${app.quizCount}', style: ts(18, color: Colors.white)),
              ]),
              const SizedBox(height: 14),
              QuizGroupRule(group: _group, dark: true),
              const SizedBox(height: 14),
              const QuizRanking(dark: true),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Chunky(
        height: 76,
        color: C.yellow,
        shadow: C.yellowD,
        radius: 26,
        depth: 7,
        onTap: () => _start(app),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.play_arrow_rounded, color: C.ink, size: 36),
          const SizedBox(width: 6),
          Text(app.t('start').toUpperCase(), style: ts(30)),
        ]),
      ),
    ]);
  }

  Widget _play(AppState app) {
    final q = _q;
    if (q == null) return const SizedBox.shrink();
    final now = _endAt > 0 ? _endAt : DateTime.now().millisecondsSinceEpoch;
    final left = _total - _idx - (_flash != null ? 1 : 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Container(
            height: 64,
            decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.timer_outlined, color: C.ink, size: 30),
              const SizedBox(width: 8),
              Text(fmtMs(now - _startAt), style: ts(34).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 108,
          height: 64,
          decoration: BoxDecoration(color: C.navy2, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(app.t('left_small'), style: ts(12, color: C.soft2, weight: FontWeight.w800)),
            Text('$left', style: ts(28, color: Colors.white, height: 1)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: (_idx + (_flash != null ? 1 : 0)) / _total,
          minHeight: 12,
          color: C.green,
          backgroundColor: C.navy2,
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Stack(children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: C.navy2, borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.all(14),
              alignment: Alignment.center,
              child: TaskLine(task: q, typed: _val, size: 50, color: Colors.white, boxColor: C.yellow, signColor: C.yellow),
            ),
          ),
          if (_flash != null) FeedbackOverlay(ok: _flash == 'ok', dark: true),
        ]),
      ),
      const SizedBox(height: 12),
      Keypad(
        dark: true,
        keyHeight: 62,
        okEnabled: _val.isNotEmpty && _flash == null,
        onDigit: (d) {
          if (_flash != null) return;
          setState(() {
            if (_val.length < 3) _val += d;
          });
        },
        onDelete: () {
          if (_val.isEmpty) return;
          setState(() => _val = _val.substring(0, _val.length - 1));
        },
        onOk: () => _submit(app),
      ),
    ]);
  }

  Widget _done(AppState app) {
    final o = _outcome;
    final grp = _group == 0 ? '${app.sign(Op.add)} ${app.sign(Op.sub)}' : '${app.sign(Op.mul)} ${app.sign(Op.div)}';
    String title = '';
    String note = '';
    if (o != null) {
      if (o.isRecord) {
        title = app.t('new_record').replaceAll('{p}', '${o.place}');
        note = (o.onPodium ? app.t('on_podium') : app.t('in_table')).replaceAll('{g}', grp);
      } else {
        title = app.t('place_list').replaceAll('{p}', '${o.place}');
        final r = o.record;
        note = o.recordPlace > 0
            ? app.t('record_stays').replaceAll('{p}', '${o.recordPlace}')
            : (r == null ? '' : '${app.t('your_record')}: ${r.correct} ✓ · ${fmtMs(r.ms)}');
      }
    }
    Widget tile(Color bg, IconData icon, String n, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              Icon(icon, color: Colors.white, size: 28),
              Text(n, style: ts(44, color: Colors.white, height: 1.05)),
              Text(label, style: ts(14, color: Colors.white70, weight: FontWeight.w800)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 10),
      Text('${app.t('quiz_end')} · $grp', style: ts(16, color: C.soft2, weight: FontWeight.w800), textAlign: TextAlign.center),
      FittedBox(fit: BoxFit.scaleDown, child: Text(app.me.name, style: ts(48, color: Colors.white))),
      const SizedBox(height: 14),
      Row(children: [
        tile(const Color(0xFF1F6E46), Icons.check_rounded, '$_good', app.t('correct_pl')),
        const SizedBox(width: 12),
        tile(const Color(0xFF7A2230), Icons.close_rounded, '$_bad', app.t('wrong_pl')),
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${app.t('time')}: ${fmtMs(_endAt - _startAt)}', style: ts(16, color: C.soft2, weight: FontWeight.w800)),
        const SizedBox(width: 14),
        const Icon(Icons.star_rounded, color: C.yellow, size: 20),
        Text(' +$_earned', style: ts(16, color: C.yellow)),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: C.yellow, borderRadius: BorderRadius.circular(26)),
        child: Row(children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
            child: Text('${o?.place ?? '-'}.', style: ts(38, color: C.yellow)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(21, height: 1.15)),
              const SizedBox(height: 2),
              Text(note, style: ts(14, color: const Color(0xFF4A3A00), weight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      const Spacer(),
      Gap(gap: 12, children: [
        Chunky(
          height: 60,
          color: C.navy2,
          shadow: C.navyD,
          radius: 20,
          onTap: () => Navigator.of(context).maybePop(),
          child: Text(app.t('menu'), style: ts(18, color: Colors.white)),
        ),
        Chunky(
          height: 60,
          color: C.green,
          shadow: C.greenD,
          radius: 20,
          onTap: () => setState(() => _phase = 'intro'),
          child: Text(app.t('again'), style: ts(18, color: Colors.white)),
        ),
      ]),
    ]);
  }
}


/// Small coloured operation blocks, as on the menu tiles.
class OpMini extends StatelessWidget {
  final Op op;
  final double size;
  const OpMini({super.key, required this.op, this.size = 34});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: C.op(op),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: C.opD(op), offset: const Offset(0, 3))],
      ),
      child: Text(app.sign(op),
          textScaler: TextScaler.noScaling,
          style: ts(size * 0.62, color: Colors.white, height: 1.0).copyWith(leadingDistribution: TextLeadingDistribution.even)),
    );
  }
}

/// Fixed rules of one quiz group: coloured blocks + two lines of text.
class QuizGroupRule extends StatelessWidget {
  final int group;
  final bool dark;
  const QuizGroupRule({super.key, required this.group, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = group == 0 ? Op.add : Op.mul;
    final b = group == 0 ? Op.sub : Op.div;
    final line1 = group == 0 ? app.t('rule_as1') : app.t('rule_md1');
    final line2 = (group == 0 ? app.t('rule_as2') : app.t('rule_md2'))
        .replaceAll('{m}', app.sign(Op.mul))
        .replaceAll('{d}', app.sign(Op.div));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OpMini(op: a),
      const SizedBox(width: 6),
      OpMini(op: b),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line1, style: ts(15, color: dark ? Colors.white : C.ink, height: 1.3)),
          const SizedBox(height: 2),
          Text(line2, style: ts(14, color: dark ? C.soft2 : C.inkSoft, weight: FontWeight.w700, height: 1.3)),
        ]),
      ),
    ]);
  }
}

/// How the quiz result is ranked, in plain words.
class QuizRanking extends StatelessWidget {
  final bool dark;
  const QuizRanking({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final main = dark ? Colors.white : C.ink;
    final soft = dark ? C.soft2 : C.inkSoft;
    Widget point(String n, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.yellow, shape: BoxShape.circle),
              child: Text(n, style: ts(13, height: 1.0)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: ts(14, color: soft, weight: FontWeight.w700, height: 1.35))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.emoji_events_rounded, color: C.yellow, size: 20),
        const SizedBox(width: 8),
        Text(app.t('ranking_title'), style: ts(15, color: main)),
      ]),
      point('1', app.t('ranking_1')),
      point('2', app.t('ranking_2')),
    ]);
  }
}
