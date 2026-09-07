/// مستحقات مدرّب لشهر معيّن — الساعات ومبلغها محسوبان من حصصه المسجَّلة
/// فعلياً (class_sessions)، كل حصة بسعر الساعة الملتقَط لحظة تسجيلها —
/// فتغيّر سعر المدرّب لاحقاً لا يمسّ حساب شهر مضى.
class TrainerPayroll {
  const TrainerPayroll({
    required this.trainerId,
    required this.fullName,
    required this.hours,
    required this.amount,
    required this.isPaid,
  });

  final String trainerId;
  final String fullName;
  final double hours;
  final double amount;
  final bool isPaid;
}
