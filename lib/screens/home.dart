import 'package:flutter/material.dart';

import '../state.dart';
import '../ui.dart';
import 'column.dart';
import 'exercise.dart';
import 'history.dart';
import 'leaderboard.dart';
import 'onboarding.dart';
import 'parent_gate.dart';
import 'quiz.dart';
import 'settings.dart';
import 'table.dart';

Future<void> openSettings(BuildContext context) async {
  final ok = await ParentGate.ask(context);
  if (!ok || !context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _starsInfo = false;

  void _go(BuildContext context, Widget screen, {bool needsFull = true}) {
    final app = AppScope.read(context);
    if (needsFull && app.locked) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfferScreen()));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _starsCard(AppState app) {
    Widget row(int n, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            SizedBox(
              width: 66,
              child: n > 0
                  ? Row(children: [for (var i = 0; i < n; i++) const Icon(Icons.star_rounded, color: Color(0xFFE8A400), size: 21)])
                  : Text('+3', style: ts(17, color: const Color(0xFFB07800))),
            ),
            Expanded(child: Text(text, style: ts(14, weight: FontWeight.w800, height: 1.3))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7DD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.yellow, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(app.t('stars_title'), style: ts(17))),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: C.ink),
              tooltip: app.t('close'),
              onPressed: () => setState(() => _starsInfo = false),
            ),
          ]),
          Text(app.t('stars_intro'), style: ts(14, color: C.inkSoft, weight: FontWeight.w700, height: 1.35)),
          row(3, app.t('stars_3')),
          row(2, app.t('stars_2')),
          row(1, app.t('stars_1')),
          row(0, app.t('stars_record')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.me;
    final locked = app.locked;

    Widget opTile(Op op) => Chunky(
          height: 120,
          color: C.op(op),
          shadow: C.opD(op),
          radius: 24,
          depth: 6,
          onTap: () => _go(context, ModePickScreen(op: op)),
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(app.sign(op), style: ts(50, color: Colors.white, height: 1)),
                const SizedBox(height: 2),
                FittedBox(child: Text(app.opName(op), style: ts(17, color: Colors.white, weight: FontWeight.w800))),
              ]),
            ),
            if (locked) Positioned(top: 10, right: 10, child: LockDot(color: C.opD(op))),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- header ----
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(p: me, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PopupMenuButton<String>(
                      offset: const Offset(0, 40),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      tooltip: app.t('switch_user'),
                      onSelected: (id) {
                        if (id == '_manage') {
                          openSettings(context);
                        } else {
                          app.setActive(id);
                        }
                      },
                      itemBuilder: (_) => [
                        for (final p in app.profiles)
                          PopupMenuItem<String>(
                            value: p.id,
                            child: Row(children: [
                              Avatar(p: p, size: 36),
                              const SizedBox(width: 12),
                              Expanded(child: Text(p.name, style: ts(17))),
                              if (p.id == me.id) const Icon(Icons.check_rounded, color: C.green),
                            ]),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: '_manage',
                          child: Row(children: [
                            const Icon(Icons.add_rounded, color: C.blue),
                            const SizedBox(width: 10),
                            Expanded(child: Text(app.t('manage_users'), style: ts(15, color: C.blue, weight: FontWeight.w800))),
                          ]),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Flexible(
                            child: Text(app.t('hi').replaceAll('{name}', me.name),
                                style: ts(21), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.expand_more_rounded, color: C.ink),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => setState(() => _starsInfo = !_starsInfo),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                        decoration: BoxDecoration(
                          color: _starsInfo ? const Color(0xFFFFF0C2) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _starsInfo ? C.yellow : C.line, width: 2),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFE8A400), size: 18),
                          const SizedBox(width: 3),
                          Text('${me.stars} ${app.t('stars')}', style: ts(14, color: C.inkSoft, weight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          Icon(_starsInfo ? Icons.expand_less_rounded : Icons.info_outline_rounded, color: C.inkSoft, size: 17),
                        ]),
                      ),
                    ),
                  ]),
                ),
                IconBox(icon: Icons.settings_rounded, tooltip: app.t('settings'), onTap: () => openSettings(context)),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _starsInfo ? _starsCard(app) : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 14),

              // ---- trial / buy banner ----
              if (!app.purchased) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(locked ? app.t('trial_over') : app.t('trial_left').replaceAll('{h}', '${app.trialHoursLeft}'),
                            style: ts(16, color: Colors.white)),
                        Text(app.t('unlock_forever'), style: ts(13, color: C.soft2, weight: FontWeight.w700)),
                      ]),
                    ),
                    Chunky(
                      height: 50,
                      color: C.green,
                      shadow: C.greenD,
                      radius: 15,
                      depth: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfferScreen())),
                      child: Text(app.t('buy'), style: ts(19, color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              // ---- multiplication table ----
              Chunky(
                height: 132,
                color: C.yellow,
                shadow: C.yellowD,
                radius: 26,
                depth: 7,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                onTap: () => _go(context, const TableScreen(), needsFull: false),
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app.t('table_title'), style: ts(25, height: 1.05)),
                      const SizedBox(height: 6),
                      Text(app.t('table_sub'), style: ts(15, color: const Color(0xFF4A3A00), weight: FontWeight.w700)),
                    ]),
                  ),
                  Text(app.sign(Op.mul), style: ts(64, height: 1)),
                ]),
              ),
              const SizedBox(height: 16),
              SectionLabel(app.t('exercises')),
              Gap(gap: 14, children: [opTile(Op.add), opTile(Op.sub)]),
              const SizedBox(height: 8),
              Gap(gap: 14, children: [opTile(Op.mul), opTile(Op.div)]),
              const SizedBox(height: 8),
              Chunky(
                height: 96,
                color: C.pink,
                shadow: C.pinkD,
                radius: 24,
                depth: 6,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                onTap: () => _go(context, const ColumnScreen()),
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app.t('column_title'), style: ts(21, color: Colors.white)),
                      Text(app.t('column_sub'), style: ts(14, color: const Color(0xFFFFE3EC), weight: FontWeight.w700)),
                    ]),
                  ),
                  if (locked) const LockDot(color: C.pinkD) else const Icon(Icons.view_column_rounded, color: Colors.white, size: 40),
                ]),
              ),
              const SizedBox(height: 16),
              SectionLabel(app.t('compete')),
              Gap(gap: 14, children: [
                Chunky(
                  height: 116,
                  color: C.ink,
                  shadow: const Color(0xFF0E1230),
                  radius: 24,
                  depth: 6,
                  onTap: () => _go(context, const QuizScreen()),
                  child: Stack(children: [
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.timer_outlined, color: C.yellow, size: 44),
                        Text(app.t('quiz'), style: ts(22, color: Colors.white)),
                      ]),
                    ),
                    if (locked) const Positioned(top: 10, right: 10, child: LockDot(color: C.ink)),
                  ]),
                ),
                Chunky(
                  height: 116,
                  color: Colors.white,
                  shadow: C.yellowD,
                  border: C.yellow,
                  borderWidth: 3,
                  radius: 24,
                  depth: 6,
                  onTap: () => _go(context, const LeaderboardScreen(), needsFull: false),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events_rounded, color: C.yellow, size: 44),
                    Text(app.t('leaderboard'), style: ts(18), textAlign: TextAlign.center),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Chunky(
                height: 56,
                radius: 18,
                border: C.line,
                onTap: () => _go(context, const HistoryScreen(), needsFull: false),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.bar_chart_rounded, color: C.ink),
                  const SizedBox(width: 8),
                  Text(app.t('my_progress'), style: ts(17)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
