import 'package:material_ui/material_ui.dart';

class AppColors {
  AppColors._();

  static const Color coral = Color(0xFFFF5A36);

  static const Color lightBg = Color(0xFFFAF7F2);
  static const Color lightText = Color(0xFF1F1F1F);
  static const Color lightField = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E0DA);

  static const Color darkBg = Color(0xFF1B1713);
  static const Color darkText = Color(0xFFF5F0EA);
  static const Color darkField = Color(0xFF26211C);
  static const Color darkBorder = Color(0xFF403A33);

  static const Color error = Color(0xFFD32F2F);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        text: AppColors.lightText,
        field: AppColors.lightField,
        border: AppColors.lightBorder,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        bg: AppColors.darkBg,
        text: AppColors.darkText,
        field: AppColors.darkField,
        border: AppColors.darkBorder,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color text,
    required Color field,
    required Color border,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.coral,
      onPrimary: Colors.white,
      secondary: AppColors.coral,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: field,
      onSurface: text,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: border, width: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: text),
        bodyLarge: TextStyle(color: text),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        hintStyle: TextStyle(color: text.withValues(alpha: 0.45)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.coral, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.coral,
          backgroundColor: field,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.coral, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.coral),
      ),
    );
  }
}
