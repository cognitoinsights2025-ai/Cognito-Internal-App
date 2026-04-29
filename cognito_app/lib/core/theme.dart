import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═════════════════════════════════════════════════════════════════════════════
// COGNITO INSIGHTS — MULTI-THEME SYSTEM
// 4 themes: Light, Dark, Purple Nebula, Ocean Breeze
// ═════════════════════════════════════════════════════════════════════════════

enum AppThemeMode { light, dark, purple, ocean }

// ─────────────────────────────────────────────────────────────────────────────
// COLOR PALETTES
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // These are defaults (light theme) — overridden via ThemeProvider
  static const Color bgPrimary   = Color(0xFFF1F5F9);
  static const Color bgSecondary = Color(0xFFFFFFFF);
  static const Color bgCard      = Color(0xFFFFFFFF);
  static const Color bgSubtle    = Color(0xFFF8FAFC);

  static const Color primary     = Color(0xFF1E3A8A);
  static const Color primaryMid  = Color(0xFF2563EB);
  static const Color primaryLight= Color(0xFF3B82F6);
  static const Color primaryTint = Color(0xFFEFF6FF);

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textTertiary  = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF94A3B8);

  static const Color border       = Color(0xFFE2E8F0);
  static const Color borderFocus  = Color(0xFF2563EB);

  static const Color success      = Color(0xFF10B981);
  static const Color successTint  = Color(0xFFECFDF5);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningTint  = Color(0xFFFFFBEB);
  static const Color error        = Color(0xFFEF4444);
  static const Color errorTint    = Color(0xFFFEF2F2);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoTint     = Color(0xFFEFF6FF);
  static const Color purple       = Color(0xFF8B5CF6);
  static const Color purpleTint   = Color(0xFFF5F3FF);
  static const Color amber        = Color(0xFFF59E0B);
  static const Color amberTint    = Color(0xFFFFFBEB);
  static const Color emerald      = Color(0xFF10B981);
  static const Color emeraldTint  = Color(0xFFECFDF5);
  static const Color rose         = Color(0xFFEF4444);
  static const Color roseTint     = Color(0xFFFEF2F2);
  static const Color cyan         = Color(0xFF06B6D4);
  static const Color cyanTint     = Color(0xFFECFEFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
  );
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DECORATION HELPER
// ─────────────────────────────────────────────────────────────────────────────
class CardDecor {
  static BoxDecoration standard({double borderRadius = 14, Color? color}) {
    return BoxDecoration(
      color: color ?? AppColors.bgCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration tinted(Color tint, {double borderRadius = 14}) {
    return BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: tint.withValues(alpha: 0.5)),
    );
  }

  static BoxDecoration primary({double borderRadius = 14}) {
    return BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryMid.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME PROVIDER — Manages theme switching
// ─────────────────────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.light;
  AppThemeMode get mode => _mode;

  void setTheme(AppThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  ThemeData get themeData {
    switch (_mode) {
      case AppThemeMode.light:
        return AppTheme.lightTheme;
      case AppThemeMode.dark:
        return AppTheme.darkTheme;
      case AppThemeMode.purple:
        return AppTheme.purpleTheme;
      case AppThemeMode.ocean:
        return AppTheme.oceanTheme;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  // ═══════════════════════════ LIGHT THEME ═══════════════════════════
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      scaffoldBg: const Color(0xFFF1F5F9),
      surfaceColor: Colors.white,
      primaryColor: const Color(0xFF1E3A8A),
      secondaryColor: const Color(0xFF2563EB),
      onPrimary: Colors.white,
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF334155),
      textMuted: const Color(0xFF94A3B8),
      borderColor: const Color(0xFFE2E8F0),
      cardColor: Colors.white,
      appBarBg: Colors.white,
      inputFill: const Color(0xFFF8FAFC),
      snackBg: const Color(0xFF0F172A),
    );
  }

  // ═══════════════════════════ DARK THEME ════════════════════════════
  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBg: const Color(0xFF0B1120),
      surfaceColor: const Color(0xFF111827),
      primaryColor: const Color(0xFF6C5CE7),
      secondaryColor: const Color(0xFF818CF8),
      onPrimary: Colors.white,
      textPrimary: const Color(0xFFF1F5F9),
      textSecondary: const Color(0xFFCBD5E1),
      textMuted: const Color(0xFF64748B),
      borderColor: const Color(0xFF1E293B),
      cardColor: const Color(0xFF111827),
      appBarBg: const Color(0xFF0B1120),
      inputFill: const Color(0xFF1E293B),
      snackBg: const Color(0xFF334155),
    );
  }

  // ═══════════════════════════ PURPLE NEBULA ═════════════════════════
  static ThemeData get purpleTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBg: const Color(0xFF0D0221),
      surfaceColor: const Color(0xFF170B3B),
      primaryColor: const Color(0xFF8B5CF6),
      secondaryColor: const Color(0xFFA78BFA),
      onPrimary: Colors.white,
      textPrimary: const Color(0xFFF5F3FF),
      textSecondary: const Color(0xFFDDD6FE),
      textMuted: const Color(0xFF7C3AED),
      borderColor: const Color(0xFF2E1065),
      cardColor: const Color(0xFF170B3B),
      appBarBg: const Color(0xFF0D0221),
      inputFill: const Color(0xFF1E0A4E),
      snackBg: const Color(0xFF4C1D95),
    );
  }

  // ═══════════════════════════ OCEAN BREEZE ══════════════════════════
  static ThemeData get oceanTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBg: const Color(0xFF0A1628),
      surfaceColor: const Color(0xFF0E1F3D),
      primaryColor: const Color(0xFF06B6D4),
      secondaryColor: const Color(0xFF22D3EE),
      onPrimary: Colors.white,
      textPrimary: const Color(0xFFECFEFF),
      textSecondary: const Color(0xFFA5F3FC),
      textMuted: const Color(0xFF0891B2),
      borderColor: const Color(0xFF164E63),
      cardColor: const Color(0xFF0E1F3D),
      appBarBg: const Color(0xFF0A1628),
      inputFill: const Color(0xFF153A52),
      snackBg: const Color(0xFF155E75),
    );
  }

  // ─────── BUILDER ───────
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBg,
    required Color surfaceColor,
    required Color primaryColor,
    required Color secondaryColor,
    required Color onPrimary,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color borderColor,
    required Color cardColor,
    required Color appBarBg,
    required Color inputFill,
    required Color snackBg,
  }) {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
      displayMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
      displaySmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
      bodyLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
      bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: textMuted),
      labelLarge: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: 0.5),
      labelSmall: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: textMuted, letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: AppColors.error,
        onPrimary: onPrimary,
        onSecondary: onPrimary,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      cardColor: cardColor,
      dividerColor: borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x0A000000),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFill,
        selectedColor: primaryColor.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
