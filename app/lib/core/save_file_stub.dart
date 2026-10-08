import 'dart:typed_data';

import 'errors.dart';

/// خارج الويب: لم يُبنَ بعد (التطبيق يُنشر ويباً اليوم).
Future<void> saveFile(Uint8List bytes, {required String filename, required String mimeType}) async {
  throw const UserFacingError('التحميل متاح من المتصفح حالياً.');
}
