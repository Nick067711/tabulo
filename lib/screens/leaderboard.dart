import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../ui.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _group = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(
                title: app.t('leaderboard'),
                actions: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchiveListScreen())),
                    icon: const Icon(Icons.inventory_2_outlined, color: C.ink, size: 20),
                    label: Text(app.t('archive'), style: ts(14)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GroupSwitch(group: _group, onChanged: (g) => setState(() => _group = g)),
              const SizedBox(height: 8),
              Text(app.t('board_sub').replaceAll('{n}', '${app.quizCount}'),
                  style: ts(13, color: C.inkSoft, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Expanded(child: BoardWidget(entries: app.boardOf(_group), total: app.quizCount)),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupSwitch extends StatelessWidget {
  final int group;
  final ValueChanged<int> onChanged;
  const GroupSwitch({super.key, required this.group, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget sq(Op op) => Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.op(op), borderRadius: BorderRadius.circular(10)),
          child: Text(app.sign(op), style: ts(20, color: Colors.white, height: 1)),
        );
    Widget btn(int g, Op a, Op b) => Chunky(
          height: 52,
          depth: 4,
          radius: 16,
          border: group == g ? C.ink : C.line,
          borderWidth: group == g ? 3 : 2,
          shadow: group == g ? C.ink : C.line,
          onTap: () => onChanged(g),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [sq(a), const SizedBox(width: 6), sq(b)]),
        );
    return Gap(children: [btn(0, Op.add, Op.sub), btn(1, Op.mul, Op.div)]);
  }
}

/// Podium (records) + list of other results, 10 places visible, the rest after "expand".
class BoardWidget extends StatefulWidget {
  final List<LbEntry> entries;
  final int total;
  const BoardWidget({super.key, required this.entries, required this.total});
  @override
  State<BoardWidget> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final colors = <String, int>{for (final p in app.profiles) p.id: p.color};
    if (widget.entries.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_outlined, size: 64, color: C.sand),
          const SizedBox(height: 8),
          Text(app.t('board_empty'), style: ts(16, color: C.inkSoft, weight: FontWeight.w800), textAlign: TextAlign.center),
        ]),
      );
    }
    final view = buildBoardView(widget.entries);
    final rest = _expanded ? view.rest : view.rest.take(7).toList();
    final hidden = view.rest.length - 7;

    Widget avatar(LbEntry e, double size) {
      final ci = colors[e.profileId] ?? 0;
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: C.avatar(ci), shape: BoxShape.circle),
        child: Text(e.name.isEmpty ? '?' : String.fromCharCode(e.name.runes.first).toUpperCase(),
            style: ts(size * 0.45, color: C.avatarText(ci))),
      );
    }

    Widget podiumCol(int i) {
      if (i >= view.podium.length) return const SizedBox(width: 104);
      final e = view.podium[i];
      const heights = [96.0, 78.0, 66.0];
      const fills = [C.yellow, Color(0xFFD5D9E6), Color(0xFFE9B48C)];
      return SizedBox(
        width: 104,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          avatar(e, 40),
          const SizedBox(height: 2),
          Text(e.name, style: ts(15), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Container(
            height: heights[i],
            width: double.infinity,
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: fills[i],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(6)),
            ),
            child: Column(children: [
              Text('${i + 1}', style: ts(22, height: 1)),
              Text('${e.correct}/${widget.total}', style: ts(13)),
              Text(fmtMs(e.ms), style: ts(12, weight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 172,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [podiumCol(1), const SizedBox(width: 8), podiumCol(0), const SizedBox(width: 8), podiumCol(2)],
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.sand, width: 2)),
          child: rest.isEmpty
              ? Center(child: Text(app.t('board_only_podium'), style: ts(14, color: C.inkSoft, weight: FontWeight.w700)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: rest.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 2, thickness: 2, color: C.paper),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return SizedBox(
                        height: 28,
                        child: Row(children: [
                          SizedBox(width: 30, child: Text(app.t('col_place'), style: ts(11, color: C.inkSoft))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(app.t('col_name'), style: ts(11, color: C.inkSoft))),
                          SizedBox(width: 64, child: Text(app.t('col_correct'), style: ts(11, color: C.inkSoft), textAlign: TextAlign.center)),
                          SizedBox(width: 64, child: Text(app.t('col_time'), style: ts(11, color: C.inkSoft), textAlign: TextAlign.right)),
                        ]),
                      );
                    }
                    final e = rest[i - 1];
                    return SizedBox(
                      height: 50,
                      child: Row(children: [
                        SizedBox(width: 30, child: Text('${i + 3}', style: ts(16, color: C.inkSoft), textAlign: TextAlign.center)),
                        const SizedBox(width: 8),
                        avatar(e, 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.name, style: ts(16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(fmtShortDate(e.date), style: ts(11, color: C.inkSoft, weight: FontWeight.w800)),
                          ]),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text('${e.correct}/${widget.total}', style: ts(15, color: C.greenD), textAlign: TextAlign.center),
                        ),
                        SizedBox(width: 64, child: Text(fmtMs(e.ms), style: ts(15), textAlign: TextAlign.right)),
                      ]),
                    );
                  },
                ),
        ),
      ),
      if (hidden > 0) ...[
        const SizedBox(height: 8),
        Chunky(
          height: 48,
          depth: 4,
          radius: 16,
          border: C.line,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_expanded ? app.t('collapse') : app.t('expand').replaceAll('{n}', '$hidden'), style: ts(16)),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.ink),
          ]),
        ),
      ],
    ]);
  }
}

class ArchiveListScreen extends StatelessWidget {
  const ArchiveListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(title: app.t('archive')),
            const SizedBox(height: 12),
            Text(app.t('archive_info'), style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 12),
            if (app.archives.isEmpty)
              Expanded(child: Center(child: Text(app.t('archive_empty'), style: ts(16, color: C.inkSoft))))
            else
              Expanded(
                child: ListView(children: [
                  for (final a in app.archives)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Chunky(
                        radius: 20,
                        depth: 4,
                        border: C.sand,
                        padding: const EdgeInsets.all(14),
                        alignment: Alignment.centerLeft,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArchiveTableScreen(archive: a))),
                        child: Row(children: [
                          const Icon(Icons.inventory_2_outlined, color: C.ink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${app.t('quiz')}: ${a.count} ${app.t('tasks_word')}', style: ts(17)),
                              Text('${fmtDate(a.from).split(',').first} – ${fmtDate(a.to).split(',').first}',
                                  style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: C.inkSoft),
                        ]),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class ArchiveTableScreen extends StatefulWidget {
  final LbArchive archive;
  const ArchiveTableScreen({super.key, required this.archive});
  @override
  State<ArchiveTableScreen> createState() => _ArchiveTableScreenState();
}

class _ArchiveTableScreenState extends State<ArchiveTableScreen> {
  int _group = 0;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = widget.archive;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(
              title: app.t('archive'),
              subtitle: '${app.t('quiz')}: ${a.count} ${app.t('tasks_word')} · ${app.t('read_only')}',
            ),
            const SizedBox(height: 10),
            GroupSwitch(group: _group, onChanged: (g) => setState(() => _group = g)),
            const SizedBox(height: 10),
            Expanded(
              child: BoardWidget(
                key: ValueKey('arch$_group'),
                entries: a.entries.where((e) => e.group == _group).toList(),
                total: a.count,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
