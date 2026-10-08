import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/features/auth/login_identifier.dart';

void main() {
  test('البريد الكامل يمرّ كما هو (بأحرف صغيرة)', () {
    expect(loginEmailFor(' Admin@Nawah.test '), 'admin@nawah.test');
  });
  test('اسم مستخدم الطالب يُلحَق به النطاق الداخلي', () {
    expect(loginEmailFor('diyar.a'), 'diyar.a@$studentEmailDomain');
    expect(loginEmailFor('Diyar.A'), 'diyar.a@$studentEmailDomain');
  });
  test('المدخلات غير الصالحة ترجع null', () {
    expect(loginEmailFor('ab'), isNull); // أقصر من ٣
    expect(loginEmailFor('ديار'), isNull); // ليس ASCII
    expect(loginEmailFor('a b c'), isNull);
    expect(loginEmailFor('x@y'), isNull);
  });
}
