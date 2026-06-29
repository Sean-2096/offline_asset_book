import 'package:flutter/material.dart';

class AssetBookPalette extends ThemeExtension<AssetBookPalette> {
  const AssetBookPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.positive,
    required this.negative,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color accent;
  final Color accentSoft;
  final Color positive;
  final Color negative;
  final Color info;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  @override
  AssetBookPalette copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? positive,
    Color? negative,
    Color? info,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return AssetBookPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      info: info ?? this.info,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AssetBookPalette lerp(ThemeExtension<AssetBookPalette>? other, double t) {
    if (other is! AssetBookPalette) return this;

    return AssetBookPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      info: Color.lerp(info, other.info, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

extension AssetBookThemeColors on BuildContext {
  AssetBookPalette get assetBookColors {
    return Theme.of(this).extension<AssetBookPalette>()!;
  }
}

class AppTheme {
  static const darkPalette = AssetBookPalette(
    background: Color(0xFF08090D),
    surface: Color(0xFF111318),
    card: Color(0xFF161820),
    border: Color(0xFF23252D),
    accent: Color(0xFFC8A951),
    accentSoft: Color(0xFFE8D48B),
    positive: Color(0xFF2DD4BF),
    negative: Color(0xFFFF6B6B),
    info: Color(0xFF60A5FA),
    textPrimary: Color(0xFFF1F1F3),
    textSecondary: Color(0xFF8B8D97),
    textMuted: Color(0xFF5A5C66),
  );

  static const lightPalette = AssetBookPalette(
    background: Color(0xFFF7F4ED),
    surface: Color(0xFFFFFCF6),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2D8C7),
    accent: Color(0xFF9A6A1E),
    accentSoft: Color(0xFFD8A642),
    positive: Color(0xFF0F8F78),
    negative: Color(0xFFD34B45),
    info: Color(0xFF2E6CB9),
    textPrimary: Color(0xFF1F211F),
    textSecondary: Color(0xFF69645A),
    textMuted: Color(0xFF9A9283),
  );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        palette: darkPalette,
      );

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AssetBookPalette palette,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'PingFang SC',
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.border,
      extensions: [palette],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.accent,
        onPrimary: palette.background,
        secondary: palette.accentSoft,
        onSecondary: palette.background,
        error: palette.negative,
        onError: palette.background,
        surface: palette.surface,
        onSurface: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.background,
          disabledBackgroundColor: palette.card,
          disabledForegroundColor: palette.textSecondary,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.accent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.card,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
