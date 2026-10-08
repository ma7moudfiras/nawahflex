import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/core/push_state.dart';
import 'package:nawahflex_app/features/notifications/app_notification.dart';

void main() {
  group('AppNotification', () {
    final n = AppNotification.fromMap({
      'id': 'n1',
      'kind': 'badge',
      'title': 'شارة جديدة لديار',
      'body': '«أول نموذج»',
      'student_id': 's1',
      'read_at': null,
      'created_at': '2026-10-07T10:00:00Z',
    });

    test('parses unread', () {
      expect(n.isRead, isFalse);
      expect(n.studentId, 's1');
    });

    test('target follows the role (same as send-push)', () {
      expect(n.targetPath(isParent: true, isStudent: false), '/kids/s1');
      expect(n.targetPath(isParent: false, isStudent: true), '/me');
      expect(n.targetPath(isParent: false, isStudent: false), isNull);
    });
  });

  test('relativeTime', () {
    final now = DateTime(2026, 10, 7, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'الآن');
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), 'قبل 5 د');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), 'قبل 3 س');
    expect(relativeTime(now.subtract(const Duration(days: 1)), now: now), 'أمس');
    expect(relativeTime(DateTime(2026, 9, 1), now: now), '1/9/2026');
  });

  group('decidePushState', () {
    PushState d({bool api = true, bool pm = true, bool ios = false, bool standalone = false, String perm = 'default'}) =>
        decidePushState(hasNotificationApi: api, hasPushManager: pm, isIos: ios, standalone: standalone, permission: perm);

    test('iPhone in Safari must install to the home screen first', () {
      expect(d(api: false, pm: false, ios: true), PushState.needsInstall);
    });
    test('old browser without push', () {
      expect(d(pm: false), PushState.unsupported);
    });
    test('permission states', () {
      expect(d(), PushState.notAsked);
      expect(d(perm: 'granted'), PushState.granted);
      expect(d(perm: 'denied'), PushState.denied);
      expect(d(ios: true, standalone: true, perm: 'granted'), PushState.granted);
    });
  });
}
