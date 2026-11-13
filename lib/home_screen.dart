import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const RingsLogo(size: 80),
              const SizedBox(height: 24),
              Text(
                'Вы вошли в SVOI',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                    ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  email,
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => _signOut(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
                child: const Text('Выйти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
