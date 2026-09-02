/// حالات الحضور — تقابل قيد status في جدول public.attendance.
class AttendanceStatus {
  AttendanceStatus._();

  static const present = 'present';
  static const absent = 'absent';
  static const late = 'late';
  static const excused = 'excused';

  static const all = [present, absent, late, excused];

  static const labels = <String, String>{
    present: 'حاضر',
    absent: 'غائب',
    late: 'متأخر',
    excused: 'معذور',
  };
}
