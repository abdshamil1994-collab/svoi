import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);
  static final ValueNotifier<bool> privateProfile = ValueNotifier(false);
  static final ValueNotifier<bool> hideLikes = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = ThemeMode.values[prefs.getInt('theme_mode') ?? 0];
    privateProfile.value = prefs.getBool('privacy_private') ?? false;
    hideLikes.value = prefs.getBool('privacy_hide_likes') ?? false;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  static Future<void> setPrivateProfile(bool value) async {
    privateProfile.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_private', value);
  }

  static Future<void> setHideLikes(bool value) async {
    hideLikes.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_hide_likes', value);
  }
}
