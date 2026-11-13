import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'auth_gate.dart';
import 'login_screen.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const SvoiApp());
}

class SvoiApp extends StatelessWidget {
  const SvoiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVOI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _initialScreen(),
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
