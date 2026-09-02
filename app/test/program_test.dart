import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/programs/program.dart';

void main() {
  Program p({int? min, int? max}) => Program(
        id: 'x',
        title: 'RoboMission Elementary',
        description: 'وصف',
        isPublished: true,
        createdAt: DateTime(2026),
        ageMin: min,
        ageMax: max,
      );

  group('ageRangeLabel', () {
    test('حدّان يعطيان "من–إلى سنة"', () => expect(p(min: 8, max: 11).ageRangeLabel, '8–11 سنة'));
    test('حدّ أدنى فقط', () => expect(p(min: 12).ageRangeLabel, 'من 12 سنة'));
    test('حدّ أعلى فقط', () => expect(p(max: 15).ageRangeLabel, 'حتى 15 سنة'));
    test('بلا حدود يرجع نصاً فارغاً', () => expect(p().ageRangeLabel, ''));
  });

  group('fitsAge', () {
    test('ضمن النطاق', () => expect(p(min: 8, max: 11).fitsAge(9), isTrue));
    test('أصغر من الحد الأدنى', () => expect(p(min: 8, max: 11).fitsAge(6), isFalse));
    test('أكبر من الحد الأعلى', () => expect(p(min: 8, max: 11).fitsAge(15), isFalse));
    test('بلا نطاق يقبل أي عمر', () => expect(p().fitsAge(99), isTrue));
  });

  group('fromMap / toInsertMap', () {
    test('يقرأ الأعمدة الصحيحة من الصف', () {
      final program = Program.fromMap({
        'id': 'p1',
        'title': 'RoboMission Junior',
        'text': 'وصف',
        'age_min': 12,
        'age_max': 15,
        'is_published': true,
        'created_at': DateTime(2026).toIso8601String(),
      });
      expect(program.title, 'RoboMission Junior');
      expect(program.ageMin, 12);
      expect(program.ageMax, 15);
    });

    test('toInsertMap يحذف الحدود الفارغة', () {
      final m = p().toInsertMap();
      expect(m.containsKey('age_min'), isFalse);
      expect(m.containsKey('age_max'), isFalse);
      expect(m['title'], 'RoboMission Elementary');
      expect(m['text'], 'وصف');
    });
  });
}
