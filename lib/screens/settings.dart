import 'package:flutter/material.dart';

import '../state.dart';
import '../ui.dart';
import 'leaderboard.dart';
import 'onboarding.dart';

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
    final tabs = [app.t('tab_general'), app.t('tab_users'), app.t('tab_exercises'), app.t('quiz')];
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
                  decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(10)),
                  child: Text(app.t('for_parent'), style: ts(12, color: C.inkSoft, weight: FontWeight.w800)),
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
                    flex: i == 1 ? 13 : (i == 2 ? 12 : (i == 3 ? 8 : 10)),
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
                            child: Text(tabs[i], style: ts(14, color: _tab == i ? C.ink : C.inkSoft)),
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
                  _ => _quiz(app),
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
      if (app.lang != 'pl' && app.lang != 'en')
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(app.t('lang_partial'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
        ),
      const SizedBox(height: 16),
      SectionLabel(app.t('mul_sign')),
      Gap(children: [
        for (final s in ['×', '•'])
          Pick(
            label: s,
            on: app.mulSign == s,
            height: 78,
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
            height: 78,
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(child: Text('7 ${app.mulSign} 8 = 56', style: ts(22))),
              FittedBox(child: Text('56 ${app.divSign} 8 = 7', style: ts(22))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      SectionLabel(app.t('test_tools'), color: C.inkSoft),
      Text(app.t('test_tools_info'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(onPressed: app.endTrialNow, child: Text(app.t('tool_end_trial'))),
        if (app.purchased) OutlinedButton(onPressed: app.undoPurchase, child: Text(app.t('tool_undo_buy'))),
        OutlinedButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            final ok = await confirmDialog(context, app.t('tool_reset'), app.t('tool_reset_text'), app.t('tool_reset_yes'), app.t('cancel'));
            if (!ok) return;
            await app.resetAll();
            nav.popUntil((r) => r.isFirst);
          },
          child: Text(app.t('tool_reset'), style: const TextStyle(color: C.red)),
        ),
      ]),
    ]);
  }

  Widget _signChild(String s, String example, bool on) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(s, style: ts(34, color: on ? Colors.white : C.ink, height: 1.1)),
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
      Gap(gap: 8, children: [
        for (final n in [10, 20, 30, 50])
          Pick(label: '$n', on: m.count == n, height: 48, onTap: () => app.updateModule(_mod, (x) => x.count = n)),
      ]),
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
          OutlinedButton(onPressed: () => app.updateModule(_mod, (x) => x.numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]), child: Text(app.t('all_1_10'))),
          OutlinedButton(onPressed: () => app.updateModule(_mod, (x) => x.numbers = [2, 3, 4, 5, 6, 7, 8, 9]), child: Text(app.t('no_1_10'))),
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
    ]);
  }

  // ---------------- Quiz ----------------

  Widget _quiz(AppState app) {
    final m = app.sign(Op.mul);
    final d = app.sign(Op.div);
    Widget rule(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a, style: ts(15)),
            const SizedBox(width: 10),
            Expanded(child: Text(b, style: ts(15, color: C.inkSoft, weight: FontWeight.w800), textAlign: TextAlign.right)),
          ]),
        );
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
          const SizedBox(height: 6),
          rule('${app.sign(Op.add)} ${app.sign(Op.sub)}', app.t('rule_as')),
          rule('$m $d', app.t('rule_md').replaceAll('{m}', m).replaceAll('{d}', d)),
          rule(app.t('ranking'), app.t('winner_rule')),
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
