import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/billing/billing_repository.dart';

void main() {
  group('BillingRepository.isEnrolledInMonth', () {
    // الخلل المُبلَّغ عنه: طالبة التحقت بشهر 9 كانت تظهر "غير مسدَّدة" لأشهر
    // 6 و7 و8 السابقة لالتحاقها فعلياً.
    test('شهر قبل بداية الاشتراك وبلا استثناء — غير محتسَب', () {
      expect(
        BillingRepository.isEnrolledInMonth(
          periodMonth: DateTime(2026, 8),
          billingStartMonth: DateTime(2026, 9),
          override: null,
        ),
        isFalse,
      );
    });

    test('شهر بداية الاشتراك نفسه — محتسَب', () {
      expect(
        BillingRepository.isEnrolledInMonth(
          periodMonth: DateTime(2026, 9),
          billingStartMonth: DateTime(2026, 9),
          override: null,
        ),
        isTrue,
      );
    });

    test('شهر بعد بداية الاشتراك — محتسَب', () {
      expect(
        BillingRepository.isEnrolledInMonth(
          periodMonth: DateTime(2026, 10),
          billingStartMonth: DateTime(2026, 9),
          override: null,
        ),
        isTrue,
      );
    });

    test('إجازة: استثناء بالإلغاء على شهر ضمن مدى الاشتراك — غير محتسَب', () {
      expect(
        BillingRepository.isEnrolledInMonth(
          periodMonth: DateTime(2026, 10),
          billingStartMonth: DateTime(2026, 9),
          override: false,
        ),
        isFalse,
      );
    });

    test('دين قديم: استثناء بالتفعيل على شهر قبل بداية الاشتراك — محتسَب', () {
      expect(
        BillingRepository.isEnrolledInMonth(
          periodMonth: DateTime(2026, 3),
          billingStartMonth: DateTime(2026, 9),
          override: true,
        ),
        isTrue,
      );
    });
  });
}
