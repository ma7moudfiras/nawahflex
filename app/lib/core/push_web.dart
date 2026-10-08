import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'push_state.dart';

typedef SaveSubscription = Future<void> Function(String endpoint, String p256dh, String auth, String userAgent);

const _worker = '/app/push-sw.js';
const _scope = '/app/';

PushState currentPushState() {
  final ua = web.window.navigator.userAgent;
  return decidePushState(
    hasNotificationApi: globalContext.has('Notification'),
    hasPushManager: globalContext.has('PushManager'),
    isIos: RegExp('iPhone|iPad|iPod').hasMatch(ua),
    standalone: web.window.matchMedia('(display-mode: standalone)').matches,
    permission: globalContext.has('Notification') ? web.Notification.permission : 'default',
  );
}

/// يُستدعى من نقرة المستخدم (المتصفح يرفض طلب الإذن بلا نقرة).
/// يرجع الحال بعد المحاولة؛ أي خطأ غير الرفض يُرمى ليظهر للمستخدم.
Future<PushState> enablePush({required String vapidPublicKey, required SaveSubscription save}) async {
  if (currentPushState() == PushState.unsupported || currentPushState() == PushState.needsInstall) {
    return currentPushState();
  }
  final permission = (await web.Notification.requestPermission().toDart).toDart;
  if (permission != 'granted') return currentPushState();

  final registration = await web.window.navigator.serviceWorker
      .register(_worker.toJS, web.RegistrationOptions(scope: _scope))
      .toDart;
  // أول تسجيل: العامل ما زال يُثبَّت، و subscribe يفشل «requires an active
  // service worker» (درس بوابة طبيعة على آيفون) — ننتظر تفعيله.
  await _whenActive(registration);

  final subscription = await registration.pushManager.getSubscription().toDart ??
      await registration.pushManager
          .subscribe(web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _base64UrlDecode(vapidPublicKey).toJS,
          ))
          .toDart;

  final p256dh = subscription.getKey('p256dh');
  final auth = subscription.getKey('auth');
  if (p256dh == null || auth == null) throw StateError('push subscription without keys');
  await save(
    subscription.endpoint,
    _base64UrlNoPad(p256dh.toDart.asUint8List()),
    _base64UrlNoPad(auth.toDart.asUint8List()),
    web.window.navigator.userAgent,
  );
  return PushState.granted;
}

/// اشتراك هذا الجهاز إن وُجد — بلا سؤال ولا اشتراك جديد.
Future<String?> currentPushEndpoint() async {
  try {
    if (!globalContext.has('PushManager')) return null;
    final registration = await web.window.navigator.serviceWorker.getRegistration(_scope).toDart;
    final sub = await registration?.pushManager.getSubscription().toDart;
    return sub?.endpoint;
  } catch (_) {
    return null;
  }
}

/// عند تسجيل الخروج: يلغي اشتراك الجهاز عند خادم Push أيضاً.
Future<void> unsubscribePush() async {
  try {
    if (!globalContext.has('PushManager')) return;
    final registration = await web.window.navigator.serviceWorker.getRegistration(_scope).toDart;
    final sub = await registration?.pushManager.getSubscription().toDart;
    if (sub != null) await sub.unsubscribe().toDart;
  } catch (_) {
    // أفضل جهد: صفّ القاعدة يُحذف على كل حال، وخادم Push يجيب 410 لاحقاً.
  }
}

Future<void> _whenActive(web.ServiceWorkerRegistration registration) async {
  if (registration.active != null) return;
  final done = Completer<void>();
  final pending = registration.installing ?? registration.waiting;
  if (pending != null) {
    void onChange(web.Event _) {
      if (pending.state == 'activated' && !done.isCompleted) done.complete();
    }

    pending.addEventListener('statechange', onChange.toJS);
  }
  unawaited(web.window.navigator.serviceWorker.ready.toDart.then((_) {
    if (!done.isCompleted) done.complete();
  }));
  await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
}

Uint8List _base64UrlDecode(String s) => base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

String _base64UrlNoPad(Uint8List bytes) => base64Url.encode(bytes).replaceAll('=', '');
