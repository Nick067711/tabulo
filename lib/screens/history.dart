import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../ui.dart';
import 'column.dart';
import 'exercise.dart';

Widget kindBadge(AppState app, String kind, {double size = 46}) {
  Color c;
  String s;
  switch (kind) {
    case 'add':
    case 'sub':
    case 'mul':
    case 'div':
      final op = opFromName(kind);
      c = C.op(op);
      s = app.sign(op);
      break;
    case 'table':
      c = C.yellow;
      s = app.sign(Op.mul);
      break;
    case 'column':
      c = C.pink;
      s = '47';
      break;
    default:
      c = C.ink;
      s = 'Q';
  }
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * 0.32)),
    child: Text(s, style: ts(size * (s.length > 1 ? 0.4 : 0.56), color: kind == 'table' ? C.ink : Colors.white, height: 1)),
  );
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';

  bool _match(Session s) {
    switch (_filter) {
      case 'all':
        return true;
      case 'quiz':
        return s.kind.startsWith('quiz');
      default:
        return s.kind == _filter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final mine = app.sessionsOf(app.me.id);
    final list = mine.where(_match).toList();
    final total = mine.fold<int>(0, (a, s) => a + s.total);
    final correct = mine.fold<int>(0, (a, s) => a + s.correct);
    final ms = mine.fold<int>(0, (a, s) => a + s.ms);
    final pct = total == 0 ? 0 : correct * 100 ~/ total;
    final hours = ms ~/ 3600000;
    final mins = (ms % 3600000) ~/ 60000;

    Widget stat(String big, String small, {Color c = C.ink}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.sand, width: 2)),
            child: Column(children: [
              FittedBox(child: Text(big, style: ts(22, color: c))),
              Text(small, style: ts(12, color: C.inkSoft, weight: FontWeight.w800)),
            ]),
          ),
        );

    final filters = <List<String>>[
      ['all', app.t('all_short')],
      ['add', app.sign(Op.add)],
      ['sub', app.sign(Op.sub)],
      ['mul', app.sign(Op.mul)],
      ['div', app.sign(Op.div)],
      ['table', app.t('table_short')],
      ['column', app.t('column_short')],
      ['quiz', app.t('quiz')],
    ];
    Widget chip(List<String> f) {
      final on = _filter == f[0];
      return GestureDetector(
        onTap: () => setState(() => _filter = f[0]),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? C.ink : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? C.ink : C.line, width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(f[1], style: ts(f[1].length > 2 ? 15 : 20, color: on ? Colors.white : C.ink)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(title: app.t('my_progress'), subtitle: app.me.name),
            const SizedBox(height: 12),
            Row(children: [
              stat('${mine.length}', app.plural(mine.length, 'sessions')),
              const SizedBox(width: 8),
              stat('$pct%', app.t('correct_word'), c: C.greenD),
              const SizedBox(width: 8),
              stat(hours > 0 ? '$hours h $mins' : '$mins min', app.t('total_time')),
            ]),
            const SizedBox(height: 12),
            Gap(gap: 6, children: [for (final f in filters.take(5)) chip(f)]),
            const SizedBox(height: 6),
            Gap(gap: 6, children: [for (final f in filters.skip(5)) chip(f)]),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(app.t('no_sessions'), style: ts(16, color: C.inkSoft), textAlign: TextAlign.center))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final err = s.mistakes.length;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s))),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.sand, width: 2)),
                            child: Row(children: [
                              kindBadge(app, s.kind),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(fmtDate(s.date), style: ts(16)),
                                  Text('${kindLabel(app, s.kind)} · ${s.total} · ${fmtMs(s.ms).split(',').first}',
                                      style: ts(13, color: C.inkSoft, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(color: err > 0 ? C.redBg : C.greenBg, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  err > 0 ? app.t('to_fix_n').replaceAll('{n}', '$err') : app.t('no_errors'),
                                  style: ts(12, color: err > 0 ? const Color(0xFFA61E1E) : C.greenD),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: C.inkSoft),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = session;
    final avg = s.total == 0 ? 0 : s.ms ~/ s.total;
    Widget stat(String label, String value, {Color c = C.ink}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.sand, width: 2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: ts(13, color: C.inkSoft, weight: FontWeight.w800)),
              FittedBox(child: Text(value, style: ts(26, color: c))),
            ]),
          ),
        );
    final canRetry = s.mistakes.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(title: kindLabel(app, s.kind), subtitle: '${fmtDate(s.date)} · ${app.me.name}', badge: kindBadge(app, s.kind, size: 44)),
            const SizedBox(height: 12),
            Row(children: [
              stat(app.t('total_time_one'), fmtMs(s.ms).split(',').first),
              const SizedBox(width: 10),
              stat(app.t('avg_per_task'), '${(avg / 1000).toStringAsFixed(1)} s'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              stat(app.t('correct_word_cap'), '${s.correct} / ${s.total}', c: C.greenD),
              const SizedBox(width: 10),
              stat(app.t('mistakes_word'), '${s.mistakes.length}', c: C.red),
            ]),
            if (s.desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.paper, borderRadius: BorderRadius.circular(16)),
                child: Text('${app.t('settings_used')}: ${s.desc}', style: ts(14, weight: FontWeight.w800)),
              ),
            ],
            const SizedBox(height: 12),
            Text(app.t('mistake_list'), style: ts(17)),
            const SizedBox(height: 8),
            Expanded(
              child: s.mistakes.isEmpty
                  ? Center(child: Text(app.t('no_errors_long'), style: ts(16, color: C.greenD)))
                  : ListView.separated(
                      itemCount: s.mistakes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = s.mistakes[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.sand, width: 2)),
                          child: Row(children: [
                            Expanded(child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(app.fullText(m.task), style: ts(24)))),
                            if (m.given.isNotEmpty) ...[
                              const Icon(Icons.close_rounded, color: C.red, size: 18),
                              Text('${app.t('typed')} ${m.given}', style: ts(14, color: const Color(0xFFA61E1E))),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
            if (canRetry) ...[
              const SizedBox(height: 12),
              Chunky(
                height: 62,
                color: C.orange,
                shadow: C.orangeD,
                radius: 22,
                depth: 6,
                onTap: () {
                  final tasks = s.mistakes.map((m) => m.task).toList();
                  final Widget screen = s.kind == 'column'
                      ? ColumnScreen(tasks: tasks)
                      : ExerciseScreen(
                          op: ['add', 'sub', 'mul', 'div'].contains(s.kind) ? opFromName(s.kind) : (s.kind == 'table' ? Op.mul : null),
                          choice: false,
                          tasks: tasks,
                          kind: s.kind == 'table' ? 'mul' : null,
                        );
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
                },
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.replay_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${app.t('fix_mistakes')} (${s.mistakes.length})', style: ts(20, color: Colors.white)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
