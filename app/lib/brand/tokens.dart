// ============================================================================
// أكاديمية نواة — رموز الهوية البصرية لتطبيق Flutter
// ----------------------------------------------------------------------------
// ⚠️ هذا الملف مرآة لـ site/css/tokens.css — القيم يجب أن تبقى متطابقة حرفياً.
//    عند تغيير أي لون أو خط، غيّره في الملفين معاً.
//
// الهوية: حبر كحلي على ورق دافئ، ولون توقيع واحد — القرميدي.
//
// الاستخدام:
//    import 'package:nawahflex_app/brand/tokens.dart';
//    MaterialApp(theme: NawahTheme.light, ...)
// ============================================================================

import 'package:flutter/material.dart';

class NawahColors {
  NawahColors._();

  // الحبر والورق                                    ← tokens.css
  static const ink       = Color(0xFF1B2A41);  // --c-ink       الكحلي
  static const inkDeep   = Color(0xFF121D2E);  // --c-ink-deep
  static const inkSoft   = Color(0xFF26364F);  // --c-ink-soft
  static const inkLine   = Color(0xFF3A4A63);  // --c-ink-line  حدود على الكحلي
  static const inkTint   = Color(0xFFE3E7EE);  // --c-ink-tint  خلفية العنصر المختار
  static const paper     = Color(0xFFF7F5F0);  // --c-paper
  static const paperDeep = Color(0xFFEFECE5);  // --c-paper-deep
  static const card      = Color(0xFFFFFFFF);  // --c-card

  // لون التوقيع — القرميدي. على خلفيته يكون النص onAccent لا الأبيض.
  static const accent     = Color(0xFFE2552B); // --c-accent
  static const accentInk  = Color(0xFFB23C17); // --c-accent-ink  نص صغير ملوّن
  static const accentSoft = Color(0xFFFBE3DA); // --c-accent-soft
  static const onAccent   = Color(0xFF0E1726); // --c-on-accent

  // الحدود
  static const border     = Color(0xFFDDD8CE); // --c-border
  static const borderSoft = Color(0xFFE9E5DD); // --c-border-soft

  // النصوص
  static const text       = Color(0xFF1B2A41); // --c-text
  static const textSoft   = Color(0xFF4A5263); // --c-text-soft
  static const textMuted  = Color(0xFF687082); // --c-text-muted
  static const textInvert = Color(0xFFFFFFFF); // --c-text-invert
  static const invertSoft = Color(0xFFB9C0CC); // --c-invert-soft  نص ثانوي على الكحلي

  // الحالات
  static const ok        = Color(0xFF1F7A3E);  // --c-ok
  static const okSoft    = Color(0xFFE6F2EA);  // --c-ok-soft
  static const err       = Color(0xFFB42318);  // --c-err
  static const errSoft   = Color(0xFFFBE9E7);  // --c-err-soft

  // ألوان وظيفية للرسوم والحالات                     ← --c-data-*
  static const blue   = Color(0xFF2563EB);
  static const cyan   = Color(0xFF0E7490);
  static const violet = Color(0xFF6D28D9);
  static const green  = Color(0xFF10B981);
  static const rose   = Color(0xFFE11D48);

  // أسماء أدوار — تُبقي شاشات اللوحة تعمل دون أن تعرف القيم:
  // «الأساسي» في الهوية الجديدة هو الكحلي، كما في أزرار الموقع.
  static const primary     = ink;
  static const primaryDark = inkDeep;
  static const primarySoft = inkTint;
  static const bg          = card;
  static const bgAlt       = paper;
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
  static const display = 'Alexandria';
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
          secondary: NawahColors.accent,
          onSecondary: NawahColors.onAccent,
          tertiary: NawahColors.cyan,
          surface: NawahColors.card,
          error: NawahColors.err,
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
        // ⚠️ fontFamily صريح هنا ضرورة لا زينة: styleFrom يبني TextStyle
        // جديداً لا يرث خط الثيم، فيسقط النص العربي إلى الخط الافتراضي
        // (Roboto) الذي لا يملك محارف عربية فيظهر مربّعات فارغة.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: NawahColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: NawahFonts.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: NawahFonts.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: NawahFonts.body,
              fontWeight: FontWeight.w600,
            ),
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
