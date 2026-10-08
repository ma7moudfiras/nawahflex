import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'errors.dart';

/// يرسل أخطاء اللوحة الحيّة إلى جدول client_errors (تقرؤه الإدارة فقط)،
/// كي نعرف بالخلل قبل أن يشتكي منه أحد بلقطة شاشة.
///
/// يغذّيه FlutterError.onError و PlatformDispatcher.onError (main.dart)
/// و [userMessageFor] — المكان الذي يمرّ منه كل تحميل أو حفظ فاشل.
///
/// لا يرمي ولا يُبطئ: التقرير الذي يفشل إرساله يُهمَل. في الجلسة الواحدة
/// يتجاهل تكرار الرسالة نفسها ويتوقّف بعد [maxPerSession]، كي لا تُغرق شاشة
/// معطوبة الجدول. و [WriteDenied] جواب صلاحية لا خلل، فلا يُبلَّغ عنه.
class ErrorReporter {
  ErrorReporter({
    required this._send,
    required this._currentUserId,
    this.maxPerSession = 20,
  });

  /// يقرأ المستخدم الحالي ويُدرج عبر العميل العادي — فتربط RLS كل صف بصاحبه.
  factory ErrorReporter.supabase(SupabaseClient client) => ErrorReporter(
        send: (row) => client.from('client_errors').insert(row),
        currentUserId: () => client.auth.currentUser?.id,
      );

  /// يُضبط مرة واحدة في main()؛ فارغ في الاختبارات وقبل الإقلاع.
  static ErrorReporter? instance;

  static void reportIfEnabled(Object error, [StackTrace? stack]) =>
      instance?.report(error, stack);

  final Future<void> Function(Map<String, dynamic> row) _send;
  final String? Function() _currentUserId;
  final int maxPerSession;
  final Set<String> _seen = <String>{};
  int _sent = 0;

  void report(Object error, [StackTrace? stack]) {
    if (error is WriteDenied) return;
    final userId = _currentUserId();
    if (userId == null || _sent >= maxPerSession) return;
    final message = _clip(error.toString(), 500);
    if (!_seen.add(message)) return;
    _sent++;
    final row = <String, dynamic>{
      'profile_id': userId,
      'message': message,
      if (stack != null) 'stack': _clip(stack.toString(), 4000),
      'url': _clip(Uri.base.toString(), 500),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
    unawaited(_send(row).catchError((Object _) {}));
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
