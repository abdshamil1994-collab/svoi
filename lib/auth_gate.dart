import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main_screen.dart';
import 'profile_setup_screen.dart';

Future<bool> hasProfile() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  final row = await Supabase.instance.client
      .from('profiles')
      .select('id')
      .eq('id', uid)
      .maybeSingle();
  return row != null;
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!
            ? const MainScreen()
            : const ProfileSetupScreen();
      },
    );
  }
}
