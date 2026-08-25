/// إعادة تشغيل التطبيق — تختلف حسب المنصّة.
/// الويب يعيد تحميل الصفحة؛ الجوّال يكتفي بمحاولة تهيئة جديدة عند العودة.
library;

export 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';
