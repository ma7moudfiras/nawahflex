import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/shared/money.dart';

void main() {
  test('عدد صحيح يُعرض بلا كسور', () => expect(formatMoney(120), '120 ₪'));
  test('عدد عشري يُعرض بمنزلتين', () => expect(formatMoney(99.5), '99.50 ₪'));
  test('صفر يُعرض بلا كسور', () => expect(formatMoney(0), '0 ₪'));
}
