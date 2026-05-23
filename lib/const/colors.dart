import 'package:flutter/material.dart';

class McColors {
  const McColors._();

  static const Color ink = Color(0xFF171717);
  static const Color inkSoft = Color(0xFF3F3F46);
  static const Color muted = Color(0xFF71717A);
  static const Color mutedLight = Color(0xFFA1A1AA);
  static const Color line = Color(0xFFE5E5E5);
  static const Color field = Color(0xFFF6F6F6);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF7F7F8);
  static const Color accent = Color(0xFF74512D);
  static const Color accentSoft = Color(0xFFF4EEE7);
}

class PointStayColors {
  const PointStayColors._();

  static const Color accent = Color(0xFF287A74);
  static const Color accentSoft = Color(0xFFEAF6F4);
}

class CardColors {
  const CardColors._();

  static const Color accent = Color(0xFF1666EF);
  static const Color accentSoft = Color(0xFFEAF2FF);
}

class GiftcardColors {
  const GiftcardColors._();

  static const Color accent = Color(0xFFDC7606);
  static const Color accentSoft = Color(0xFFFFF3E6);
  static const Color accentBorder = Color(0xFFE7A55C);
}

class McTextStyles {
  const McTextStyles._();

  static const TextStyle appBarTitle = TextStyle(
    color: McColors.ink,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: McColors.ink,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    color: McColors.ink,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    color: McColors.inkSoft,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyStrong = TextStyle(
    color: McColors.ink,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle meta = TextStyle(
    color: McColors.muted,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const TextStyle micro = TextStyle(
    color: McColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle tabSelected = TextStyle(
    color: McColors.ink,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle tab = TextStyle(
    color: McColors.muted,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}

class MileageTheme {
  const MileageTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: McColors.accent,
      onPrimary: Colors.white,
      secondary: McColors.accent,
      onSecondary: Colors.white,
      surface: McColors.surface,
      onSurface: McColors.ink,
      error: Color(0xFFDC2626),
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: McColors.background,
      fontFamily: 'NanumGothic',
      primaryColor: McColors.accent,
      visualDensity: VisualDensity.compact,
      appBarTheme: const AppBarTheme(
        backgroundColor: McColors.surface,
        foregroundColor: McColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: McTextStyles.appBarTitle,
        iconTheme: IconThemeData(color: McColors.ink, size: 23),
        actionsIconTheme: IconThemeData(color: McColors.ink, size: 23),
      ),
      textTheme: const TextTheme(
        titleLarge: McTextStyles.appBarTitle,
        titleMedium: McTextStyles.sectionTitle,
        titleSmall: McTextStyles.cardTitle,
        bodyLarge: McTextStyles.body,
        bodyMedium: McTextStyles.body,
        bodySmall: McTextStyles.meta,
        labelLarge: McTextStyles.bodyStrong,
        labelMedium: McTextStyles.meta,
        labelSmall: McTextStyles.micro,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: McColors.field,
        hintStyle: McTextStyles.body.copyWith(color: McColors.mutedLight),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: McColors.accent, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: McColors.line,
        thickness: 0.7,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: McColors.field,
        selectedColor: McColors.accentSoft,
        disabledColor: McColors.field,
        labelStyle: McTextStyles.meta,
        secondaryLabelStyle: McTextStyles.meta.copyWith(
          color: McColors.accent,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: McColors.accent,
        side: const BorderSide(color: McColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: McColors.accent,
          textStyle: McTextStyles.bodyStrong,
          visualDensity: VisualDensity.compact,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: McColors.accent,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: McColors.accent,
      ),
    );
  }
}

const PRIMARY_COLOR = Color(0xFF066D97);
final LIGHT_GREY_COLOR = Colors.grey[200]!;
final DARK_GREY_COLOR = Colors.grey[600]!;
final TEXT_FIELD_FILL_COLOR = Colors.grey[300]!;

const economyColor = Color(0xFF1976D2); // Deep Blue
const businessColor = Color(0xFFFFB300); // Gold
const firstColor = Color(0xFF8B1E3F); // Burgundy
