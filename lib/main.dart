import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'auth_gate.dart';
import 'login_screen.dart';
import 'messages_screen.dart';
import 'presence.dart';
import 'settings.dart';
import 'supabase_config.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  final startedAt = DateTime.now();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await AppSettings.load();
  PresenceService.instance.start();
  MessagesBadgeService.instance.start();

  // Splash — минимум 2 секунды или до готовности.
  final elapsed = DateTime.now().difference(startedAt);
  const minDuration = Duration(seconds: 2);
  if (elapsed < minDuration) {
    await Future.delayed(minDuration - elapsed);
  }

  runApp(const SvoiApp());
  FlutterNativeSplash.remove();
}

class SvoiApp extends StatelessWidget {
  const SvoiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'SVOI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: _initialScreen(),
        );
      },
    );
  }

  Widget _initialScreen() {
    try {
      if (Supabase.instance.client.auth.currentSession != null) {
        return const AuthGate();
      }
    } catch (_) {
      // Supabase не инициализирован (например, в тестах) — показываем вход.
    }
    return const LoginScreen();
  }
}
