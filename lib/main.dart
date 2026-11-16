import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'state.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final app = AppState();
  await app.load();
  runApp(TabuloApp(app: app));
}

class TabuloApp extends StatelessWidget {
  final AppState app;
  const TabuloApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: app,
      child: MaterialApp(
        title: 'Tabulo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: C.cream,
          colorScheme: ColorScheme.fromSeed(seedColor: C.orange, surface: C.cream),
          snackBarTheme: const SnackBarThemeData(backgroundColor: C.ink, behavior: SnackBarBehavior.floating),
        ),
        // Large system font sizes would push digits out of the fixed answer boxes.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.1)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return app.onboarded ? const HomeScreen() : const WelcomeScreen();
  }
}
