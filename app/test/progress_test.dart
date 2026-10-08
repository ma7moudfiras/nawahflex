import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/brand/level_frame.dart';
import 'package:nawahflex_app/features/progress/progress_models.dart';
import 'package:nawahflex_app/features/progress/progress_sheets.dart';

void main() {
  group('StudentProgress', () {
    StudentProgress p(int points, int min, int? next, {int attended = 0, int total = 0}) => StudentProgress(
          studentId: 's',
          points: points,
          level: 2,
          levelTitle: 'شرارة',
          levelMinPoints: min,
          nextLevelPoints: next,
          sessionsAttended: attended,
          sessionsTotal: total,
        );

    test('نسبة التقدّم داخل المستوى', () {
      expect(p(150, 150, 400).levelFraction, 0);
      expect(p(275, 150, 400).levelFraction, 0.5);
      expect(p(275, 150, 400).pointsToNext, 125);
    });

    test('المستوى الأخير ممتلئ ولا مستوى بعده', () {
      final max = p(2000, 1400, null);
      expect(max.isMaxLevel, isTrue);
      expect(max.levelFraction, 1);
      expect(max.pointsToNext, 0);
    });

    test('نسبة الحضور فارغة بلا سجلّ', () {
      expect(p(0, 0, 150).attendanceRate, isNull);
      expect(p(0, 0, 150, attended: 3, total: 4).attendanceRate, 75);
    });

    test('يُقرأ من ناتج student_progress', () {
      final x = StudentProgress.fromMap({
        'student_id': 'a',
        'points': 40,
        'level': 1,
        'level_title': 'نواة',
        'level_min_points': 0,
        'next_level_points': 150,
        'sessions_attended': 2,
        'sessions_total': 2,
        'badges_count': 1,
        'projects_count': 0,
      });
      expect(x.points, 40);
      expect(x.nextLevelPoints, 150);
      expect(x.attendanceRate, 100);
    });

    test('الطالب الجديد في المستوى الأول', () {
      const e = StudentProgress.empty('z');
      expect(e.level, 1);
      expect(e.points, 0);
    });
  });

  test('درجات المهارة الأربع بأسمائها', () {
    expect(SkillLevel.label(1), 'مبتدئ');
    expect(SkillLevel.label(4), 'خبير');
    expect(SkillLevel.label(9), '—');
  });

  testWidgets('الإطار يُرسم لكل مستوى بلا أخطاء، والمستوى خارج المدى يُقصّ', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(
          children: [
            for (var lv = 0; lv <= 7; lv++)
              LevelFrame(level: lv, size: 64, child: InitialAvatar(initial: '$lv')),
          ],
        ),
      ),
    ));
    expect(find.byType(LevelFrame), findsNWidgets(8));
    expect(find.bySemanticsLabel(RegExp('^المستوى 1')), findsNWidgets(2)); // ٠ و١
    expect(find.bySemanticsLabel(RegExp('^المستوى 5')), findsNWidgets(3)); // ٥ و٦ و٧
    expect(t.takeException(), isNull);
  });

  testWidgets('مقياس المهارة يملأ شرائح بعدد الدرجة', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SkillMeter(level: 3)))));
    expect(find.bySemanticsLabel('متمكّن'), findsOneWidget);
  });
}
