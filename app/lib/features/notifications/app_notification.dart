import 'package:flutter/material.dart';

/// إشعار في البوابة (جدول notifications — 0017). تنشئه مُشغِّلات القاعدة.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.studentId,
    this.readAt,
  });

  final String id;

  /// badge | note | absence | certificate | project
  final String kind;
  final String title;
  final String? body;
  final String? studentId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  IconData get icon => switch (kind) {
        'badge' => Icons.military_tech_outlined,
        'note' => Icons.sticky_note_2_outlined,
        'absence' => Icons.event_busy_outlined,
        'certificate' => Icons.workspace_premium_outlined,
        'project' => Icons.precision_manufacturing_outlined,
        _ => Icons.notifications_outlined,
      };

  /// الصفحة التي يفتحها النقر — نفس منطق send-push للإشعار على الجوال.
  String? targetPath({required bool isParent, required bool isStudent}) {
    if (isParent && studentId != null) return '/kids/$studentId';
    if (isStudent) return '/me';
    return null;
  }

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        kind: m['kind'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        studentId: m['student_id'] as String?,
        readAt: m['read_at'] == null ? null : DateTime.parse(m['read_at'] as String).toLocal(),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// «قبل ٥ دقائق» بأرقام لاتينية — قصير يناسب سطراً تحت الإشعار.
String relativeTime(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} د';
  if (d.inHours < 24) return 'قبل ${d.inHours} س';
  if (d.inDays < 7) return d.inDays == 1 ? 'أمس' : 'قبل ${d.inDays} أيام';
  return '${t.day}/${t.month}/${t.year}';
}
