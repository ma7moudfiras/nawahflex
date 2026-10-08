/// حفظ ملف ولّده التطبيق (شهادة، تقرير) على جهاز المستخدم.
///
/// على الويب: رابط blob بخاصية download يُنقر برمجياً — تنزيل لا نافذة
/// منبثقة، فلا يحجبه المتصفح كما يحجب window.open (انظر open_url.dart).
library;

export 'save_file_stub.dart' if (dart.library.js_interop) 'save_file_web.dart';
