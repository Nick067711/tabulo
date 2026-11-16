import 'package:flutter/material.dart';

import '../ui.dart';
import 'parent_gate.dart';

const languageNames = [
  ['pl', 'PL', 'Polski'],
  ['en', 'EN', 'English'],
  ['de', 'DE', 'Deutsch'],
  ['es', 'ES', 'Español'],
  ['fr', 'FR', 'Français'],
  ['uk', 'UA', 'Українська'],
];

class LogoBlocks extends StatelessWidget {
  final double size;
  const LogoBlocks({super.key, this.size = 84});
  @override
  Widget build(BuildContext context) {
    Widget b(Color c, String s) => Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * 0.1)),
          child: Text(s, style: ts(size * 0.24, color: Colors.white, height: 1)),
        );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: C.yellow,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [BoxShadow(color: C.yellowD, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Expanded(child: Row(children: [Expanded(child: b(C.green, '+')), SizedBox(width: size * 0.07), Expanded(child: b(C.blue, '−'))])),
          SizedBox(height: size * 0.07),
          Expanded(child: Row(children: [Expanded(child: b(C.orange, '×')), SizedBox(width: size * 0.07), Expanded(child: b(C.purple, '÷'))])),
        ],
      ),
    );
  }
}

/// First run: language and name.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    if (app.profiles.isNotEmpty) _name.text = app.profiles.first.name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final canGo = _name.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: LogoBlocks()),
              const SizedBox(height: 14),
              Text(app.t('welcome'), style: ts(28), textAlign: TextAlign.center),
              const SizedBox(height: 22),
              SectionLabel(app.t('choose_lang')),
              for (var row = 0; row < 3; row++) ...[
                Gap(children: [
                  for (final l in languageNames.sublist(row * 2, row * 2 + 2))
                    Pick(
                      label: l[2],
                      on: app.lang == l[0],
                      color: C.blue,
                      dark: C.blueD,
                      height: 54,
                      fontSize: 17,
                      onTap: () => app.setLang(l[0], withSigns: true),
                    ),
                ]),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 14),
              SectionLabel(app.t('your_name')),
              TextField(
                controller: _name,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                style: ts(22, weight: FontWeight.w800),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: app.t('name_hint'),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: C.line, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: C.orange, width: 3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: C.inkSoft),
                const SizedBox(width: 6),
                Expanded(child: Text(app.t('name_local'), style: ts(13, color: C.inkSoft, weight: FontWeight.w700))),
              ]),
              const SizedBox(height: 28),
              Opacity(
                opacity: canGo ? 1 : 0.5,
                child: Chunky(
                  height: 64,
                  color: C.orange,
                  shadow: C.orangeD,
                  radius: 22,
                  depth: 7,
                  onTap: canGo
                      ? () {
                          FocusScope.of(context).unfocus();
                          app.ensureFirstProfile(_name.text);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfferScreen(firstRun: true)));
                        }
                      : null,
                  child: Text(app.t('next'), style: ts(23, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "KUP / TESTUJ" screen. Also shown later when a locked module is tapped.
class OfferScreen extends StatelessWidget {
  final bool firstRun;
  const OfferScreen({super.key, this.firstRun = false});

  Future<void> _buy(BuildContext context) async {
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    final ok = await ParentGate.ask(context);
    if (!ok || !context.mounted) return;
    final confirm = await confirmDialog(
      context,
      app.t('buy_test_title'),
      app.t('buy_test_text'),
      app.t('buy_test_yes'),
      app.t('cancel'),
      danger: false,
    );
    if (!confirm) return;
    app.purchase();
    if (firstRun) app.completeOnboarding();
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget feature(Color c, Widget icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: ts(16, weight: FontWeight.w800))),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!firstRun)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconBox(icon: Icons.chevron_left_rounded, onTap: () => Navigator.of(context).maybePop()),
                ),
              const SizedBox(height: 8),
              Text(app.t('hi').replaceAll('{name}', app.me.name),
                  style: ts(18, color: C.inkSoft, weight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(app.t('offer_title'), style: ts(34), textAlign: TextAlign.center),
              Text(app.t('offer_sub'), style: ts(19, color: C.inkSoft, weight: FontWeight.w800, height: 1.25), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.volume_off_rounded, color: C.yellow),
                    const SizedBox(width: 10),
                    Text(app.t('no_ads'), style: ts(19, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              CardBox(
                child: Column(children: [
                  feature(C.yellow, Text('×', style: ts(20)), app.t('feat_table')),
                  feature(C.green, Text('+−', style: ts(16, color: Colors.white)), app.t('feat_ops')),
                  feature(C.pink, Text('47', style: ts(15, color: Colors.white)), app.t('feat_column')),
                  feature(C.blue, const Icon(Icons.bar_chart_rounded, color: Colors.white), app.t('feat_stats')),
                ]),
              ),
              const SizedBox(height: 22),
              if (!app.purchased)
                Chunky(
                  height: 76,
                  color: C.green,
                  shadow: C.greenD,
                  radius: 24,
                  depth: 7,
                  onTap: () => _buy(context),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${app.t('buy')} · ${app.t('price')}', style: ts(26, color: Colors.white, height: 1.1)),
                    Text(app.t('buy_once'), style: ts(14, color: const Color(0xFFE2F7EA), weight: FontWeight.w800)),
                  ]),
                ),
              const SizedBox(height: 10),
              if (!app.trialUsed)
                Chunky(
                  height: 66,
                  color: Colors.white,
                  shadow: C.ink,
                  border: C.ink,
                  borderWidth: 3,
                  radius: 22,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => TrialInfoScreen(firstRun: firstRun))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(app.t('try'), style: ts(22, height: 1.1)),
                    Text(app.t('try_sub'), style: ts(13, color: C.inkSoft, weight: FontWeight.w800)),
                  ]),
                )
              else if (!app.purchased)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    app.trialActive
                        ? app.t('trial_left').replaceAll('{h}', '${app.trialHoursLeft}')
                        : app.t('trial_used'),
                    style: ts(15, color: C.inkSoft, weight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (firstRun && app.trialUsed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chunky(
                    height: 56,
                    onTap: () {
                      app.completeOnboarding();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: Text(app.t('to_menu'), style: ts(18)),
                  ),
                ),
              TextButton(
                onPressed: () => toast(context, app.t('restore_test')),
                child: Text(app.t('restore'),
                    style: ts(15, color: C.blue, weight: FontWeight.w800).copyWith(decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrialInfoScreen extends StatelessWidget {
  final bool firstRun;
  const TrialInfoScreen({super.key, this.firstRun = false});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget row(IconData icon, Color c, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c, size: 26),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: ts(16, weight: FontWeight.w800, height: 1.35))),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: C.blue,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [BoxShadow(color: C.blueD, offset: Offset(0, 9))],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('24', style: ts(64, color: Colors.white, height: 1)),
                    Text(app.t('hours'), style: ts(18, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              Text(app.t('trial_title'), style: ts(30, height: 1.1), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              CardBox(
                child: Column(children: [
                  row(Icons.check_rounded, C.green, app.t('trial_1')),
                  row(Icons.check_rounded, C.green, app.t('trial_2')),
                  row(Icons.info_outline_rounded, C.blue, app.t('trial_3')),
                ]),
              ),
              const Spacer(),
              Chunky(
                height: 70,
                color: C.blue,
                shadow: C.blueD,
                radius: 24,
                depth: 7,
                onTap: () {
                  app.startTrial();
                  if (firstRun) app.completeOnboarding();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: Text('OK', style: ts(28, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
