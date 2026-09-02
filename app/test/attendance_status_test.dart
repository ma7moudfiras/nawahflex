import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/features/attendance/attendance_status.dart';

void main() {
  test('كل حالة في all لها تسمية عربية في labels', () {
    for (final s in AttendanceStatus.all) {
      expect(AttendanceStatus.labels.containsKey(s), isTrue, reason: 'الحالة $s بلا تسمية');
    }
  });

  test('أربع حالات فقط، تطابق قيد status في القاعدة', () {
    expect(AttendanceStatus.all, ['present', 'absent', 'late', 'excused']);
  });
}
