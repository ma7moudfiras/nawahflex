import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:nawahflex_app/core/image_prep.dart';

void main() {
  test('صورة كبيرة تُصغَّر إلى ١٦٠٠ على أطول ضلع وتصير JPEG', () {
    final big = img.Image(width: 3000, height: 2000);
    final png = Uint8List.fromList(img.encodePng(big));
    final out = prepareImage(png)!;
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, kMaxImageSide);
    expect(decoded.height, (2000 * kMaxImageSide / 3000).round());
  });

  test('الصورة الطولية تُصغَّر من ارتفاعها', () {
    final tall = img.Image(width: 1000, height: 4000);
    final out = prepareImage(Uint8List.fromList(img.encodePng(tall)))!;
    final d = img.decodeJpg(out)!;
    expect(d.height, kMaxImageSide);
    expect(d.width, 400);
  });

  test('الصورة الصغيرة لا تُكبَّر', () {
    final small = img.Image(width: 800, height: 600);
    final d = img.decodeJpg(prepareImage(Uint8List.fromList(img.encodePng(small)))!)!;
    expect(d.width, 800);
  });

  test('ملف ليس صورة يرجع null', () {
    expect(prepareImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
