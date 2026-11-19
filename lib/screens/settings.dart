import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../state.dart';
import '../ui.dart';
import 'home.dart';
import 'leaderboard.dart';
import 'onboarding.dart';
import 'quiz.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;
  Op _mod = Op.mul;
  final _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tabs = [app.t('tab_general'), app.t('tab_users'), app.t('tab_exercises'), app.t('quiz'), 'i'];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(
              title: app.t('settings'),
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.red, width: 2),
                  ),
                  child: Text(app.t('for_parent'), style: ts(12, color: Colors.white, weight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    flex: const [10, 13, 12, 8, 4][i],
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tab == i ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _tab == i ? const [BoxShadow(color: Color(0xFFE2D2B4), offset: Offset(0, 3))] : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: i == 4
                                ? Icon(Icons.info_outline_rounded, size: 22, color: _tab == i ? C.blue : C.inkSoft)
                                : Text(tabs[i], style: ts(14, color: _tab == i ? C.ink : C.inkSoft)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: switch (_tab) {
                  0 => _general(app),
                  1 => _users(app),
                  2 => _modules(app),
                  3 => _quiz(app),
                  _ => const InfoTab(),
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------- General ----------------

  Widget _general(AppState app) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel(app.t('language')),
      for (var row = 0; row < 3; row++) ...[
        Gap(children: [
          for (final l in languageNames.sublist(row * 2, row * 2 + 2))
            Pick(label: l[2], on: app.lang == l[0], color: C.blue, dark: C.blueD, height: 50, fontSize: 16, onTap: () => app.setLang(l[0])),
        ]),
        const SizedBox(height: 4),
      ],
      const SizedBox(height: 16),
      SectionLabel(app.t('mul_sign')),
      Gap(children: [
        for (final s in ['×', '•'])
          Pick(
            label: s,
            on: app.mulSign == s,
            height: 88,
            onTap: () => app.setMulSign(s),
            child: _signChild(s, '7 $s 8', app.mulSign == s),
          ),
      ]),
      const SizedBox(height: 12),
      SectionLabel(app.t('div_sign')),
      Gap(children: [
        for (final s in [':', '÷', '/'])
          Pick(
            label: s,
            on: app.divSign == s,
            color: C.purple,
            dark: C.purpleD,
            height: 88,
            onTap: () => app.setDivSign(s),
            child: _signChild(s, '56 $s 8', app.divSign == s),
          ),
      ]),
      const SizedBox(height: 12),
      CardBox(
        child: Row(children: [
          OpBadge(op: Op.mul, size: 54),
          const SizedBox(width: 8),
          OpBadge(op: Op.div, size: 54),
          const SizedBox(width: 26),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(child: Text('7 ${app.mulSign} 8 = 56', style: ts(22))),
              FittedBox(child: Text('56 ${app.divSign} 8 = 7', style: ts(22))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      SectionLabel(app.t('div_layout')),
      for (final row in const [
        ['pl', 'en'],
        ['de', 'pot'],
      ]) ...[
        Gap(children: [
          for (final l in row)
            Pick(
              label: l,
              on: app.divLayout == l,
              color: C.purple,
              dark: C.purpleD,
              height: 118,
              onTap: () => app.setDivLayout(l),
              child: _layoutChild(app, l, app.divLayout == l),
            ),
        ]),
        const SizedBox(height: 4),
      ],
      if (!app.purchased) ...[
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: C.redBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.red, width: 2)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: C.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                app.trialActive
                    ? app.t('version_trial').replaceAll('{h}', '${app.trialHoursLeft}')
                    : app.t('version_basic'),
                style: ts(14, color: C.red, weight: FontWeight.w800, height: 1.35),
              ),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 22),
      Center(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: C.red,
            side: const BorderSide(color: C.red, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.delete_forever_rounded),
          label: Text(app.t('tool_reset'), style: ts(15, color: C.red)),
          onPressed: () async {
            final nav = Navigator.of(context);
            // Asked twice, so the data cannot be erased by one accidental tap.
            final ok = await confirmDialog(context, app.t('tool_reset'), app.t('tool_reset_text'), app.t('tool_reset_yes'), app.t('cancel'));
            if (!ok || !context.mounted) return;
            final sure = await confirmDialog(context, app.t('tool_reset_q2'), app.t('tool_reset_q2_text'), 'OK', app.t('cancel'));
            if (!sure) return;
            await app.resetAll();
            nav.popUntil((r) => r.isFirst);
          },
        ),
      ),
    ]);
  }

  /// A tiny sample of how 468 : 3 is written in the given layout, with solid lines.
  Widget _layoutChild(AppState app, String l, bool on) {
    final d = app.sign(Op.div);
    final c = on ? Colors.white : C.ink;
    final st = TextStyle(fontFamily: 'monospace', fontSize: 15, height: 1.2, fontWeight: FontWeight.w800, color: c);
    Text t(String s) => Text(s, textScaler: TextScaler.noScaling, style: st);
    Widget hl([double w = 0]) => Container(height: 2, width: w == 0 ? null : w, color: c);
    Widget vl(double h) => Container(width: 2, height: h, color: c);
    // number with a line above it, the line reaching a bit further than the digits
    Widget over(String top, String bottom) => IntrinsicWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [t(top), hl(), t(bottom)]),
        );
    final Widget sample = switch (l) {
      'pl' => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          over('156  ', '468 '),
          t('$d 3'),
        ]),
      'en' => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          t('3)'),
          over('156', '468'),
        ]),
      'de' => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          t('468 $d 3 = 156'),
          t('-3'),
          t(' 16'),
        ]),
      _ => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          t('468 '),
          vl(38),
          IntrinsicWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [t(' 3  '), hl(), t(' 156')]),
          ),
        ]),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        sample,
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(app.t('dl_$l'), style: ts(13, color: on ? Colors.white : C.inkSoft, weight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _signChild(String s, String example, bool on) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(s, style: ts(34, color: on ? Colors.white : C.ink, height: 1.0)),
        const SizedBox(height: 8),
        Text(example, style: ts(13, color: on ? Colors.white70 : C.inkSoft, weight: FontWeight.w800)),
      ]);

  // ---------------- Users ----------------

  Widget _users(AppState app) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final p in app.profiles)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 66,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.sand, width: 2)),
            child: Row(children: [
              Avatar(p: p, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: ts(18)),
                  Text('${app.sessionsOf(p.id).length} ${app.t('sessions_word')} · ${p.stars} ${app.t('stars')}',
                      style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: C.blue),
                tooltip: app.t('rename'),
                onPressed: () => _rename(app, p),
              ),
              if (app.profiles.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                  tooltip: app.t('delete'),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      app.t('delete_user_q').replaceAll('{name}', p.name),
                      app.t('delete_user_text'),
                      app.t('delete'),
                      app.t('cancel'),
                    );
                    if (ok) app.removeProfile(p.id);
                  },
                ),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      SectionLabel(app.t('new_user')),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _newName,
            maxLength: 16,
            textCapitalization: TextCapitalization.words,
            style: ts(18, weight: FontWeight.w800),
            decoration: InputDecoration(
              counterText: '',
              hintText: app.t('name_hint'),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.line, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.green, width: 3)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Chunky(
          height: 54,
          color: C.green,
          shadow: C.greenD,
          radius: 16,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          onTap: () {
            final n = _newName.text.trim();
            if (n.isEmpty) return;
            app.addProfile(n);
            _newName.clear();
            FocusScope.of(context).unfocus();
          },
          child: Text(app.t('add'), style: ts(17, color: Colors.white)),
        ),
      ]),
      const SizedBox(height: 8),
      Text(app.t('users_info'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
    ]);
  }

  Future<void> _rename(AppState app, Profile p) async {
    final ctl = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(app.t('rename_title'), style: ts(20)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: ctl,
            autofocus: true,
            maxLength: 16,
            textCapitalization: TextCapitalization.words,
            style: ts(18, weight: FontWeight.w800),
            decoration: InputDecoration(
              counterText: '',
              hintText: app.t('name_hint'),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.blue, width: 3)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line, width: 2)),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: 10),
          Text(app.t('rename_info'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700, height: 1.35)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(app.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.blue),
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: Text(app.t('save')),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (name != null && name.trim().isNotEmpty) app.renameProfile(p.id, name);
  }

  // ---------------- Modules ----------------

  Widget _modules(AppState app) {
    final m = app.module(_mod);
    final isMulDiv = _mod == Op.mul || _mod == Op.div;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Gap(gap: 8, children: [
        for (final op in Op.values)
          Chunky(
            height: 54,
            depth: 4,
            radius: 16,
            color: _mod == op ? C.op(op) : Colors.white,
            shadow: _mod == op ? C.opD(op) : C.line,
            border: _mod == op ? C.op(op) : C.line,
            onTap: () => setState(() => _mod = op),
            child: Text(app.sign(op), style: ts(30, color: _mod == op ? Colors.white : C.op(op), height: 1)),
          ),
      ]),
      const SizedBox(height: 12),
      Text(app.opName(_mod), style: ts(21)),
      const SizedBox(height: 12),
      SectionLabel(app.t('tasks_in_exercise')),
      CountSlider(
        value: m.count,
        color: C.op(_mod),
        onChanged: (n) => app.updateModule(_mod, (x) => x.count = n),
      ),
      const SizedBox(height: 16),
      if (isMulDiv) ...[
        SectionLabel(app.t('which_numbers')),
        for (var row = 0; row < 2; row++) ...[
          Gap(gap: 6, children: [
            for (var n = row * 6 + 1; n <= row * 6 + 6; n++)
              Pick(
                label: '$n',
                on: m.numbers.contains(n),
                height: 46,
                onTap: () => app.updateModule(_mod, (x) {
                  if (x.numbers.contains(n)) {
                    if (x.numbers.length > 1) x.numbers.remove(n);
                  } else {
                    x.numbers.add(n);
                    x.numbers.sort();
                  }
                }),
              ),
          ]),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 6),
        Gap(gap: 8, children: [
          OutlinedButton(
            onPressed: () => app.updateModule(_mod, (x) => x.numbers = [for (var n = 1; n <= 12; n++) n]),
            child: Text(app.t('nums_all')),
          ),
          OutlinedButton(
            onPressed: () => app.updateModule(_mod, (x) => x.numbers = [2, 3, 4, 5, 6, 7, 8, 9]),
            child: Text(app.t('nums_2_9')),
          ),
        ]),
        const SizedBox(height: 6),
        Text(app.t('uk_us_note'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
      ] else ...[
        SectionLabel(app.t('number_range')),
        Gap(gap: 8, children: [
          for (var i = 0; i < AppState.ranges.length; i++)
            Pick(
              label: '${app.t('up_to')} ${AppState.ranges[i]}',
              on: m.range == i,
              height: 48,
              fontSize: 15,
              onTap: () => app.updateModule(_mod, (x) => x.range = i),
            ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line, width: 2)),
          child: Row(children: [
            Expanded(child: Text(app.t('cross_ten'), style: ts(15))),
            Switch(
              value: m.carry,
              activeTrackColor: C.green,
              onChanged: (v) => app.updateModule(_mod, (x) => x.carry = v),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 26),
      SectionLabel(app.t('advance_title')),
      _advanceCard(
        app,
        title: app.t('advance_mental'),
        auto: app.mentalAuto,
        onAuto: (v) => app.setAdvance(mAuto: v),
        options: [for (final ms in AppState.mentalDelays) (ms, ms % 1000 == 0 ? '${ms ~/ 1000} s' : '${ms / 1000} s'.replaceAll('.', app.lang == 'en' ? '.' : ','))],
        value: app.mentalDelayMs,
        onValue: (v) => app.setAdvance(mDelay: v),
      ),
      const SizedBox(height: 10),
      _advanceCard(
        app,
        title: app.t('advance_column'),
        auto: app.columnAuto,
        onAuto: (v) => app.setAdvance(cAuto: v),
        options: [for (final sec in AppState.columnDelays) (sec, '$sec s')],
        value: app.columnDelayS,
        onValue: (v) => app.setAdvance(cDelay: v),
      ),
    ]);
  }

  /// "Tap Next" or "by itself after …" for one kind of exercise.
  Widget _advanceCard(
    AppState app, {
    required String title,
    required bool auto,
    required ValueChanged<bool> onAuto,
    required List<(int, String)> options,
    required int value,
    required ValueChanged<int> onValue,
  }) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: ts(16)),
        const SizedBox(height: 10),
        Gap(gap: 8, children: [
          Pick(label: app.t('advance_tap'), on: !auto, color: C.blue, dark: C.blueD, height: 50, fontSize: 14, onTap: () => onAuto(false)),
          Pick(label: app.t('advance_auto'), on: auto, color: C.blue, dark: C.blueD, height: 50, fontSize: 14, onTap: () => onAuto(true)),
        ]),
        if (auto) ...[
          const SizedBox(height: 10),
          Text(app.t('advance_after'), style: ts(13, color: C.inkSoft, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Gap(gap: 6, children: [
            for (final o in options)
              Pick(label: o.$2, on: value == o.$1, height: 44, fontSize: 14, onTap: () => onValue(o.$1)),
          ]),
        ],
      ]),
    );
  }

  // ---------------- Quiz ----------------

  Widget _quiz(AppState app) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel(app.t('quiz_count')),
      Gap(gap: 8, children: [
        for (final n in [10, 20, 50, 100])
          Pick(
            label: '$n',
            on: app.quizCount == n,
            height: 54,
            fontSize: 20,
            onTap: () async {
              if (n == app.quizCount) return;
              final ok = await confirmDialog(
                context,
                app.t('quiz_change_q').replaceAll('{n}', '$n'),
                app.t('quiz_change_text').replaceAll('{n}', '${app.quizCount}'),
                app.t('change_btn'),
                app.t('cancel'),
              );
              if (ok) app.setQuizCount(n);
            },
          ),
      ]),
      const SizedBox(height: 14),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: C.inkSoft),
            const SizedBox(width: 6),
            Text(app.t('fixed_rules'), style: ts(13, color: C.inkSoft)),
          ]),
          const SizedBox(height: 12),
          const QuizGroupRule(group: 0),
          const SizedBox(height: 14),
          const QuizGroupRule(group: 1),
          const SizedBox(height: 16),
          const QuizRanking(),
        ]),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, color: C.blue, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(app.t('quiz_change_info'), style: ts(14, color: C.inkSoft, weight: FontWeight.w700, height: 1.35))),
      ]),
      const SizedBox(height: 14),
      Chunky(
        height: 54,
        radius: 16,
        depth: 4,
        border: C.line,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchiveListScreen())),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.inventory_2_outlined, color: C.ink),
          const SizedBox(width: 8),
          Text(app.t('archive_tables'), style: ts(16)),
        ]),
      ),
    ]);
  }
}


/// Number of tasks, 10 to 100: a number line with a point that jumps every 10.
class CountSlider extends StatelessWidget {
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  const CountSlider({super.key, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(10, 100);
    final snapped = ((v / 10).round() * 10).clamp(10, 100);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line, width: 2)),
      child: Column(children: [
        Text('$snapped', style: ts(30, color: color, height: 1.1)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: C.sand,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            activeTickMarkColor: Colors.white,
            inactiveTickMarkColor: C.inkSoft,
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          ),
          child: Slider(
            value: snapped.toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            onChanged: (d) {
              final n = d.round();
              if (n != snapped) onChanged(n);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var n = 10; n <= 100; n += 10)
              SizedBox(
                width: 22,
                child: Text('$n',
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: ts(10, color: n == snapped ? color : C.inkSoft, weight: FontWeight.w800)),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- Info ("i") ----------------

const privacyUrl = 'https://sites.google.com/view/tabmath';
const contactEmail = 'tabmath.app@gmail.com';

class InfoTab extends StatefulWidget {
  const InfoTab({super.key});
  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab> {
  bool _policy = false;

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _p(String text, {Color color = C.inkSoft}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: ts(14, color: color, weight: FontWeight.w700, height: 1.4)),
      );

  Widget _link(String label, String url, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(icon, size: 20, color: C.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: ts(15, color: C.blue, weight: FontWeight.w800).copyWith(decoration: TextDecoration.underline, decorationColor: C.blue)),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const StarsRules(),
      const SizedBox(height: 14),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.favorite_rounded, color: C.pink, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(app.t('thanks_title'), style: ts(17))),
          ]),
          _p(app.t('thanks_text')),
          _link(contactEmail, 'mailto:$contactEmail', Icons.mail_outline_rounded),
        ]),
      ),
      const SizedBox(height: 14),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.rocket_launch_rounded, color: C.purple, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(app.t('next_app_title'), style: ts(17))),
          ]),
          _p(app.t('next_app_text')),
          for (final k in ['next_app_1', 'next_app_2', 'next_app_3', 'next_app_4'])
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: ts(15, color: C.purple)),
                Expanded(child: Text(app.t(k), style: ts(14, weight: FontWeight.w800, height: 1.35))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      if (!_policy)
        Chunky(
          height: 56,
          radius: 16,
          depth: 4,
          border: C.line,
          onTap: () => setState(() => _policy = true),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.privacy_tip_outlined, color: C.ink),
            const SizedBox(width: 8),
            Text(app.t('privacy_title'), style: ts(16)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: C.ink),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.privacy_tip_outlined, color: C.ink),
              const SizedBox(width: 8),
              Expanded(child: Text(app.t('privacy_title'), style: ts(17))),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: C.ink),
                tooltip: app.t('close'),
                onPressed: () => setState(() => _policy = false),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _p(app.t('pp_lead'), color: C.ink),
                for (final k in ['pp_1', 'pp_2', 'pp_3', 'pp_4', 'pp_5', 'pp_6']) _p(app.t(k)),
                const SizedBox(height: 10),
                Text(app.t('pp_admin'), style: ts(14)),
                _p('Mikołaj Piwecki\nLeszczynowa 1, 62-069 Dąbrówka, ${app.t('country_pl')}\n${app.t('phone')}: +48 727 597 336\nE-mail: $contactEmail'),
                const SizedBox(height: 4),
                _link(app.t('pp_full'), privacyUrl, Icons.open_in_new_rounded),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: 14),
      Center(
        child: Text('TabMath · ${app.t('version')} $appVersion',
            style: ts(13, color: C.inkSoft, weight: FontWeight.w800)),
      ),
    ]);
  }
}
