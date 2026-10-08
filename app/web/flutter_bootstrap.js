{{flutter_js}}
{{flutter_build_config}}

// بلا serviceWorkerSettings عمداً: عامل Flutter (flutter_service_worker.js) مهجور،
// ونسخته الحالية «مفتاح إيقاف» يلغي تسجيل نطاقه /app/ عند تفعيله — فيمسح معه
// عامل الإشعارات push-sw.js المسجَّل على النطاق نفسه واشتراكه. لا تُعِده.
_flutter.loader.load();
