import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// أقصى ضلع للصورة المرفوعة — يكفي لعرضها بوضوح على أي شاشة.
const int kMaxImageSide = 1600;

/// يصغّر الصورة ويعيد ترميزها JPEG قبل الرفع: صورة هاتف ١٢ ميجابكسل (~٤ ميجا)
/// تصير بضع مئات من الكيلوبايت، فيُرفع أسرع على شبكة ضعيفة وتُعرض أسرع.
/// يرجع null إن لم تكن الملف صورة يمكن قراءتها.
Uint8List? prepareImage(Uint8List bytes, {int maxSide = kMaxImageSide, int quality = 82}) {
  // decodeImage يرمي (لا يرجع null) لبعض الملفات التالفة أو غير الصور.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded); // صور الهاتف تحمل الدوران في EXIF
  final resized = (oriented.width > maxSide || oriented.height > maxSide)
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? maxSide : null,
          height: oriented.height > oriented.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
