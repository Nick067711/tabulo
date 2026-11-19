// Store screenshots (Google Play): renders chosen screens at 1080 × 1920 px with real fonts.
// Run in CI after installing fonts-roboto and fonts-dejavu:
//   flutter test test/screenshots_test.dart
// The PNG files are written to screenshots/<lang>/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabmath/main.dart';
import 'package:tabmath/screens/column.dart';
import 'package:tabmath/screens/exercise.dart';
import 'package:tabmath/screens/home.dart';
import 'package:tabmath/screens/leaderboard.dart';
import 'package:tabmath/screens/quiz.dart';
import 'package:tabmath/screens/settings.dart';
import 'package:tabmath/screens/table.dart';
import 'package:tabmath/state.dart';
import 'package:tabmath/ui.dart';

const _size = Size(1080, 1920);
const _ratio = 2.625;

List<String> _find(RegExp name) {
  final out = <String>[];
  for (final dir in ['/usr/share/fonts', '/usr/local/share/fonts']) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true)) {
      if (f is File && name.hasMatch(f.uri.pathSegments.last)) out.add(f.path);
    }
  }
  return out;
}

Future<void> _family(String family, List<String> files) async {
  if (files.isEmpty) return;
  final l = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await l.load();
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  await _family('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  await _family('Roboto', _find(RegExp(r'^Roboto-(Regular|Medium|Bold|Black)\.ttf$')));
  await _family('monospace', _find(RegExp(r'^DejaVuSansMono-Bold\.ttf$')));
  await _family('serif', _find(RegExp(r'^DejaVuSerif-Bold(Italic)?\.ttf$')));
  await _family('DejaVu', _find(RegExp(r'^DejaVuSans-Bold\.ttf$')));
}

/// A family with fictional English names, stars and quiz results.
Future<AppState> _state(String lang) async {
  SharedPreferences.setMockInitialValues({});
  final app = AppState();
  await app.load();
  app.setLang(lang, withSigns: true);
  const people = [
    ('John', 145, 98, 251000, 96, 228000, 48),
    ('Emma', 127, 97, 263000, 98, 214000, 41),
    ('Mark', 96, 95, 242000, 93, 236000, 35),
    ('Nick', 88, 93, 288000, 91, 247000, 27),
    ('Lucy', 66, 90, 301000, 88, 262000, 19),
    ('Adam', 41, 86, 318000, 84, 279000, 15),
  ];
  for (final p in people) {
    final prof = app.addProfile(p.$1);
    app.setActive(prof.id);
    app.addSession(Session(
      id: app.newId(),
      profileId: prof.id,
      kind: 'mul',
      date: app.now,
      ms: 90000,
      total: 20,
      correct: 19,
      mistakes: const [],
      stars: p.$2,
    ));
    for (var i = 1; i < p.$7; i++) {
      app.addSession(Session(
        id: app.newId(),
        profileId: prof.id,
        kind: 'add',
        date: app.now,
        ms: 80000,
        total: 20,
        correct: 18,
        mistakes: const [],
      ));
    }
    app.addQuizResult(0, p.$3, p.$4);
    app.addQuizResult(1, p.$5, p.$6);
  }
  app.setActive(app.profiles.first.id);
  app.startTrial();
  app.purchase();
  app.completeOnboarding();
  return app;
}

Widget _wrap(AppState app, GlobalKey key, Widget screen) {
  final theme = appTheme();
  return RepaintBoundary(
    key: key,
    child: AppScope(
      notifier: app,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: ['DejaVu'])),
        builder: clampTextScale,
        home: screen,
      ),
    ),
  );
}

Future<void> _save(WidgetTester tester, GlobalKey key, String path) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final f = File(path)..createSync(recursive: true);
  f.writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(_loadFonts);

  for (final lang in ['pl', 'en']) {
    Future<void> shot(WidgetTester tester, String name, Widget Function() screen,
        Future<void> Function(WidgetTester t)? act) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = _ratio;
      addTearDown(tester.view.reset);
      final app = await tester.runAsync(() => _state(lang));
      final key = GlobalKey();
      await tester.pumpWidget(_wrap(app!, key, screen()));
      await tester.pump(const Duration(milliseconds: 500));
      if (act != null) await act(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await _save(tester, key, 'screenshots/$lang/$name.png');
      await tester.pumpWidget(const SizedBox()); // disposes screens and their timers
      await tester.pump(const Duration(seconds: 1));
    }

    void digits(WidgetTester tester, String s) {
      for (final ch in s.split('')) {
        tester.widget<Keypad>(find.byType(Keypad)).onDigit(ch);
      }
    }

    testWidgets('$lang 1 menu', (t) => shot(t, '1_menu', () => const HomeScreen(), null));
    testWidgets('$lang 2 settings', (t) => shot(t, '2_settings_languages', () => const SettingsScreen(), null));
    testWidgets('$lang 3 table', (t) => shot(t, '3_table_7x8', () => const TableScreen(), (t) async {
          await t.tap(find.text('56').first);
        }));
    testWidgets('$lang 4 division', (t) => shot(
          t,
          '4_division_mental',
          () => const ExerciseScreen(op: Op.div, choice: false, tasks: [Task(Op.div, 56, 7)]),
          (t) async {
            await t.tap(find.byType(HintButton));
          },
        ));
    testWidgets('$lang 5 column multiplication', (t) => shot(
          t,
          '5_column_multiplication',
          () => const ColumnScreen(tasks: [Task(Op.mul, 347, 26)]),
          (t) async {
            for (final ch in '248202'.split('')) {
              digits(t, ch);
              await t.pump(const Duration(milliseconds: 50));
            }
          },
        ));
    testWidgets('$lang 6 quiz', (t) => shot(t, '6_quiz', () => const QuizScreen(), (t) async {
          final app = AppScope.read(t.element(find.byType(QuizScreen)));
          await t.tap(find.text(app.t('start').toUpperCase()));
          for (var i = 0; i < 40; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          digits(t, '4');
          await t.pump(const Duration(milliseconds: 100));
        }));
    testWidgets('$lang 7 leaderboard', (t) => shot(t, '7_leaderboard', () => const LeaderboardScreen(), null));
    testWidgets('$lang 8 users', (t) => shot(t, '8_users_stars', () => const SettingsScreen(), (t) async {
          final app = AppScope.read(t.element(find.byType(SettingsScreen)));
          await t.tap(find.text(app.t('tab_users')));
        }));
  }
}
