import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/students/student.dart';

void main() {
  Student s({DateTime? birthDate, String? phone, String? name = 'طالب'}) => Student(
        id: 'x',
        fullName: name!,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        birthDate: birthDate,
        guardianPhone: phone,
      );

  group('العمر', () {
    test('يُحسب من تاريخ الميلاد', () {
      final now = DateTime.now();
      final tenYearsAgo = DateTime(now.year - 10, now.month, now.day);
      expect(s(birthDate: tenYearsAgo).age, 10);
    });

    test('عيد الميلاد لم يأتِ بعد هذه السنة — يُطرح واحد', () {
      final now = DateTime.now();
      // تاريخ ميلاد بعد اليوم الحالي بيوم واحد (ضمن السنة القادمة تقويمياً)
      final future = DateTime(now.year - 10, now.month, now.day).add(const Duration(days: 1));
      expect(s(birthDate: future).age, 9);
    });

    test('بلا تاريخ ميلاد يرجع null', () {
      expect(s().age, isNull);
    });
  });

  group('رابط واتساب — نفس منطق الرسائل', () {
    test('رقم محلي يتحوّل لمفتاح فلسطين', () {
      expect(s(phone: '0599123456').whatsappUrl, 'https://wa.me/970599123456');
    });

    test('بلا رقم هاتف يرجع نصاً فارغاً لا رابطاً مكسوراً', () {
      expect(s(phone: null).whatsappUrl, '');
      expect(s(phone: '').whatsappUrl, '');
    });
  });

  group('الحرف الأول', () {
    test('من أول حرف بالاسم', () => expect(s(name: 'محمود').initial, 'م'));
    test('اسم فارغ لا يكسر التطبيق', () => expect(s(name: ' ').initial, '؟'));
  });

  group('toInsertMap — لا يُرسل حقولاً فارغة', () {
    test('الحقول الاختيارية الفارغة لا تدخل الخريطة', () {
      final m = s(name: 'محمود').toInsertMap();
      expect(m.containsKey('guardian_phone'), isFalse);
      expect(m['full_name'], 'محمود');
    });

    test('الحقول المملوءة تدخل الخريطة', () {
      final m = Student(
        id: 'x', fullName: 'محمود', isActive: true, createdAt: DateTime(2026),
        guardianPhone: '0599123456',
      ).toInsertMap();
      expect(m['guardian_phone'], '0599123456');
    });
  });
}
