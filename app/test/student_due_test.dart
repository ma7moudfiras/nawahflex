import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/billing/student_due.dart';

void main() {
  StudentDue due({double amount = 120}) => StudentDue(
        id: 'd1', studentId: 's1', periodMonth: DateTime(2026, 9),
        amountDue: amount, siblingDiscountApplied: false, createdAt: DateTime(2026, 9, 1),
      );

  group('بلا استحقاق منشأ بعد', () {
    test('hasDue و isFullyPaid و isPartiallyPaid كلها false', () {
      const o = StudentDueOverview(studentId: 's1', fullName: 'x', expectedAmount: 120, siblingDiscount: false);
      expect(o.hasDue, isFalse);
      expect(o.isFullyPaid, isFalse);
      expect(o.isPartiallyPaid, isFalse);
      expect(o.balance, 120);
    });
  });

  group('استحقاق منشأ', () {
    test('بلا دفعات: غير مسدَّد، الرصيد = المبلغ كاملاً', () {
      final o = StudentDueOverview(studentId: 's1', fullName: 'x', expectedAmount: 120, siblingDiscount: false, due: due());
      expect(o.isFullyPaid, isFalse);
      expect(o.isPartiallyPaid, isFalse);
      expect(o.balance, 120);
    });

    test('دفعة جزئية: isPartiallyPaid فقط', () {
      final o = StudentDueOverview(
        studentId: 's1', fullName: 'x', expectedAmount: 120, siblingDiscount: false, due: due(), paidTotal: 50,
      );
      expect(o.isPartiallyPaid, isTrue);
      expect(o.isFullyPaid, isFalse);
      expect(o.balance, 70);
    });

    test('دفعة كاملة: isFullyPaid، الرصيد صفر أو أقل', () {
      final o = StudentDueOverview(
        studentId: 's1', fullName: 'x', expectedAmount: 120, siblingDiscount: false, due: due(), paidTotal: 120,
      );
      expect(o.isFullyPaid, isTrue);
      expect(o.isPartiallyPaid, isFalse);
      expect(o.balance, 0);
    });

    test('دفعة زائدة عن المطلوب تبقى isFullyPaid', () {
      final o = StudentDueOverview(
        studentId: 's1', fullName: 'x', expectedAmount: 120, siblingDiscount: false, due: due(), paidTotal: 150,
      );
      expect(o.isFullyPaid, isTrue);
      expect(o.balance, -30);
    });
  });
}
