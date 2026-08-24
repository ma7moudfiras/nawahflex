// ============================================================================
// نواة فليكس — رموز الهوية البصرية لتطبيق Flutter
// ----------------------------------------------------------------------------
// ⚠️ هذا الملف مرآة لـ site/css/tokens.css — القيم يجب أن تبقى متطابقة حرفياً.
//    عند تغيير أي لون أو خط، غيّره في الملفين معاً.
//
// الاستخدام (المرحلة الثانية):
//    import 'package:nawahflex/brand/tokens.dart';
//    MaterialApp(theme: NawahTheme.light, ...)
// ============================================================================

import 'package:flutter/material.dart';

class NawahColors {
  NawahColors._();

  // الألوان الأساسية
  static const ink        = Color(0xFF070C1E);
  static const inkSoft    = Color(0xFF101836);
  static const inkMuted   = Color(0xFF1B2547);

  static const primary     = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFDBEAFE);

  static const accent     = Color(0xFFF59E0B);
  static const accentSoft = Color(0xFFFEF3C7);

  static const cyan   = Color(0xFF06B6D4);
  static const violet = Color(0xFF7C3AED);
  static const green  = Color(0xFF10B981);
  static const rose   = Color(0xFFF43F5E);

  // الأسطح
  static const bg         = Color(0xFFFFFFFF);
  static const bgAlt      = Color(0xFFF6F7FB);
  static const bgWarm     = Color(0xFFFBF9F4);
  static const card       = Color(0xFFFFFFFF);
  static const border     = Color(0xFFE4E7EF);
  static const borderSoft = Color(0xFFEFF1F7);

  // النصوص
  static const text       = Color(0xFF0F172A);
  static const textSoft   = Color(0xFF475569);
  static const textMuted  = Color(0xFF7A8699);
  static const textInvert = Color(0xFFFFFFFF);
}

class NawahRadius {
  NawahRadius._();
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 22.0;
  static const xl = 32.0;
  static const full = 999.0;
}

class NawahSpacing {
  NawahSpacing._();
  static const s1 = 4.0;   static const s2 = 8.0;
  static const s3 = 12.0;  static const s4 = 16.0;
  static const s5 = 24.0;  static const s6 = 32.0;
  static const s7 = 48.0;  static const s8 = 64.0;
}

class NawahFonts {
  NawahFonts._();
  /// خط العناوين — يقابل --f-display
  static const display = 'Tajawal';
  /// خط النصوص — يقابل --f-body
  static const body = 'IBMPlexSansArabic';
}

class NawahTheme {
  NawahTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        // التطبيق عربي بالكامل — الاتجاه يُضبط في MaterialApp عبر
        // locale: Locale('ar') و Directionality.rtl
        fontFamily: NawahFonts.body,
        scaffoldBackgroundColor: NawahColors.bgAlt,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NawahColors.primary,
          primary: NawahColors.primary,
          secondary: NawahColors.cyan,
          tertiary: NawahColors.accent,
          surface: NawahColors.card,
          error: NawahColors.rose,
        ),
        textTheme: const TextTheme(
          displayLarge:  TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, color: NawahColors.ink),
          headlineMedium: TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, color: NawahColors.ink),
          titleLarge:    TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w700, color: NawahColors.ink),
          bodyMedium:    TextStyle(color: NawahColors.textSoft, height: 1.75),
        ),
        cardTheme: CardThemeData(
          color: NawahColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NawahRadius.md),
            side: const BorderSide(color: NawahColors.border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: NawahColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NawahColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NawahRadius.sm),
            borderSide: const BorderSide(color: NawahColors.border, width: 1.5),
          ),
        ),
      );
}
