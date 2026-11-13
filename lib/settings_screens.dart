import 'package:material_ui/material_ui.dart';

import 'settings.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конфиденциальность'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.privateProfile,
            builder: (context, value, _) => SwitchListTile(
              title: const Text('Приватный профиль'),
              subtitle: const Text('Посты видны только вам'),
              value: value,
              onChanged: AppSettings.setPrivateProfile,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.hideLikes,
            builder: (context, value, _) => SwitchListTile(
              title: const Text('Скрывать мои лайки'),
              subtitle: const Text('Другие не увидят, что вам понравилось'),
              value: value,
              onChanged: AppSettings.setHideLikes,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.themeMode,
        builder: (context, mode, _) => ListView(
          padding: const EdgeInsets.all(8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Тема оформления',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) => AppSettings.setThemeMode(m!),
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('Системная'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Светлая'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Тёмная'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
