import 'package:flutter/material.dart';

import '../core/config.dart';

/// أحجام التخطيط الثلاثة.
///
/// القرار المعماري: تطبيق واحد يخدم جمهورين مختلفين — الإدارة تعمل معظم
/// شغلها على المكتب (جداول عريضة، عمودان جنباً إلى جنب)، وأولياء الأمور
/// على الجوّال تقريباً حصراً. فبدل بناء تطبيقين، يبدّل هذا الملف الهيكل
/// حسب العرض المتاح ويبقى المنطق واحداً.
enum ScreenSize { mobile, tablet, desktop }

extension ScreenSizeX on BuildContext {
  ScreenSize get screen {
    final w = MediaQuery.sizeOf(this).width;
    if (w >= AppConfig.breakpointDesktop) return ScreenSize.desktop;
    if (w >= AppConfig.breakpointTablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screen == ScreenSize.mobile;
  bool get isTablet => screen == ScreenSize.tablet;
  bool get isDesktop => screen == ScreenSize.desktop;

  /// المكتب واللوحي يتشاركان التنقّل الجانبي.
  bool get isWide => screen != ScreenSize.mobile;
}

/// يختار قيمة حسب حجم الشاشة، مع تدرّج تلقائي للأصغر عند غياب قيمة.
T adaptive<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  switch (context.screen) {
    case ScreenSize.desktop:
      return desktop ?? tablet ?? mobile;
    case ScreenSize.tablet:
      return tablet ?? mobile;
    case ScreenSize.mobile:
      return mobile;
  }
}
