import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'auth_gate.dart';
import 'login_screen.dart';
import 'settings.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await AppSettings.load();
  runApp(const SvoiApp());
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
