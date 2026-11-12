import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'login_screen.dart';

void main() {
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
      home: const LoginScreen(),
    );
  }
}
