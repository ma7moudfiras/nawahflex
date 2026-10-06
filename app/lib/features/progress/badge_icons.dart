import 'package:flutter/material.dart';

/// مفتاح الأيقونة في جدول badges ← رسمها في التطبيق.
///
/// المفتاح نص في القاعدة كي تضيف الإدارة شارة دون تحديث التطبيق؛ مفتاح لا
/// يعرفه التطبيق بعد يُرسم نجمة بدل أن يختفي.
const Map<String, IconData> badgeIcons = {
  'star': Icons.star_outline_rounded,
  'build': Icons.precision_manufacturing_outlined,
  'bug': Icons.bug_report_outlined,
  'team': Icons.groups_outlined,
  'mic': Icons.mic_none_rounded,
  'calendar': Icons.event_available_outlined,
  'bulb': Icons.lightbulb_outline_rounded,
  'code': Icons.code_rounded,
  'robot': Icons.smart_toy_outlined,
  'ai': Icons.psychology_outlined,
  'science': Icons.science_outlined,
  'leader': Icons.flag_outlined,
};

IconData badgeIcon(String key) => badgeIcons[key] ?? Icons.star_outline_rounded;
