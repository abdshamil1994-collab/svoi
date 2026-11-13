import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'menu_screens.dart';
import 'settings_screens.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({
    super.key,
    required this.profile,
    required this.onOpenStats,
    required this.onSignOut,
  });

  final Map<String, dynamic>? profile;
  final VoidCallback onOpenStats;
  final VoidCallback onSignOut;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _stub(BuildContext context, String text) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openSite(BuildContext context) async {
    Navigator.of(context).pop();
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse('https://svoi.iibotnev.ru');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final username = profile?['username'] as String? ?? '';
    final avatarUrl = profile?['avatar_url'] as String?;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkField : AppColors.lightField,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person_outline,
                            size: 26, color: AppColors.coral)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text('Баланс: 0 🪙',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('💰 Баланс'),
              onTap: () => _open(context, const BalanceScreen()),
            ),
            ListTile(
              title: const Text('📊 Статистика'),
              onTap: () {
                Navigator.of(context).pop();
                onOpenStats();
              },
            ),
            ListTile(
              title: const Text('🔒 Конфиденциальность'),
              onTap: () => _open(context, const PrivacyScreen()),
            ),
            ListTile(
              title: const Text('⚙️ Настройки'),
              onTap: () => _open(context, const SettingsScreen()),
            ),
            ListTile(
              title: const Text('👥 Пригласить друзей'),
              onTap: () =>
                  _stub(context, 'Приглашение друзей появится скоро'),
            ),
            ListTile(
              title: const Text('ℹ️ О приложении'),
              onTap: () => _open(
                context,
                AboutScreen(onOpenSite: () => _openSite(context)),
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              title: const Text('🚪 Выйти'),
              onTap: () {
                Navigator.of(context).pop();
                onSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
