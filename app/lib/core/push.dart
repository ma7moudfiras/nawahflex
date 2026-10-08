/// إشعارات الجوال (Web Push) — تسجيل العامل والاشتراك، أو لا شيء خارج الويب.
///
/// العامل `web/push-sw.js` على نطاق `/app/`، و Flutter لا يسجّل عاملاً
/// (`web/flutter_bootstrap.js`) — عامله المهجور كان يلغي تسجيل النطاق فيمسح الاشتراك.
library;

export 'push_state.dart';
export 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';
