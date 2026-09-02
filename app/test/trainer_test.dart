import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/trainers/trainer.dart';

void main() {
  group('hasAccount', () {
    test('true عند وجود profile_id', () {
      final t = Trainer(id: 'x', fullName: 'أحمد', isPublished: true, createdAt: DateTime(2026), profileId: 'p1');
      expect(t.hasAccount, isTrue);
    });

    test('false بلا profile_id', () {
      final t = Trainer(id: 'x', fullName: 'أحمد', isPublished: true, createdAt: DateTime(2026));
      expect(t.hasAccount, isFalse);
    });
  });

  group('fromMap / toInsertMap', () {
    test('يقرأ الأعمدة الصحيحة', () {
      final t = Trainer.fromMap({
        'id': 't1',
        'profile_id': 'p1',
        'full_name': 'أحمد المدرّب',
        'title': 'مدرّب روبوتات',
        'bio': 'نبذة',
        'is_published': true,
        'created_at': DateTime(2026).toIso8601String(),
      });
      expect(t.fullName, 'أحمد المدرّب');
      expect(t.profileId, 'p1');
      expect(t.hasAccount, isTrue);
    });

    test('toInsertMap يحذف الحقول الفارغة', () {
      final m = Trainer(id: 'x', fullName: 'أحمد', isPublished: true, createdAt: DateTime(2026)).toInsertMap();
      expect(m.containsKey('profile_id'), isFalse);
      expect(m.containsKey('title'), isFalse);
      expect(m.containsKey('bio'), isFalse);
      expect(m['full_name'], 'أحمد');
    });
  });
}
