import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../core/errors.dart';
import '../../core/push.dart';
import '../../core/supabase.dart';
import 'app_notification.dart';

class NotificationsRepository {
  const NotificationsRepository();

  /// RLS: صاحب الإشعار وحده.
  Future<List<AppNotification>> fetchRecent({int limit = 30}) async {
    final rows = await Db.client
        .from('notifications')
        .select('id, kind, title, body, student_id, read_at, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => AppNotification.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final res = await Db.client.from('notifications').select('id').isFilter('read_at', null).count(CountOption.exact);
    return res.count;
  }

  Future<void> markRead(String id) async {
    expectRows(await Db.client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select('id'));
  }

  /// كل غير المقروء — قد يكون صفراً فلا expectRows.
  Future<void> markAllRead() async {
    await Db.client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null)
        .select('id');
  }

  // ---------- Push ----------

  Future<PushState> enableDevicePush() async {
    final key = await Db.client.rpc('push_public_key') as String?;
    if (key == null || key.isEmpty) throw const UserFacingError('إشعارات الجوال غير مهيّأة بعد على الخادم.');
    return enablePush(
      vapidPublicKey: key,
      save: (endpoint, p256dh, auth, ua) => Db.client.rpc('save_push_subscription', params: {
        'p_endpoint': endpoint,
        'p_p256dh': p256dh,
        'p_auth': auth,
        'p_user_agent': ua,
      }),
    );
  }

  /// قبل تسجيل الخروج: لا تصل إشعارات هذا المستخدم لمن يدخل بعده على الجهاز.
  /// أفضل جهد — لا يمنع الخروج إن فشل.
  Future<void> forgetThisDevice() async {
    try {
      final endpoint = await currentPushEndpoint();
      if (endpoint == null) return;
      await Db.client.from('push_subscriptions').delete().eq('endpoint', endpoint);
      await unsubscribePush();
    } catch (_) {}
  }
}
