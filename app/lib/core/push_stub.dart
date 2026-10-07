import 'push_state.dart';

typedef SaveSubscription = Future<void> Function(String endpoint, String p256dh, String auth, String userAgent);

PushState currentPushState() => PushState.unsupported;

Future<PushState> enablePush({required String vapidPublicKey, required SaveSubscription save}) async =>
    PushState.unsupported;

Future<String?> currentPushEndpoint() async => null;

Future<void> unsubscribePush() async {}
