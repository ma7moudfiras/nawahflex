/// استحقاق شهري لطالب — يقابل صفّاً في public.student_dues. المبلغ لقطة
/// محسوبة وقت الإنشاء (مجموع أسعار برامجه وقتها، بعد خصم الإخوة إن كان
/// مفعَّلاً تلك اللحظة) — لا يتغيّر بتغيّر أسعار البرامج لاحقاً.
class StudentDue {
  const StudentDue({
    required this.id,
    required this.studentId,
    required this.periodMonth,
    required this.amountDue,
    required this.siblingDiscountApplied,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final DateTime periodMonth;
  final double amountDue;
  final bool siblingDiscountApplied;
  final DateTime createdAt;

  factory StudentDue.fromMap(Map<String, dynamic> m) => StudentDue(
    id: m['id'] as String,
    studentId: m['student_id'] as String,
    periodMonth: DateTime.parse(m['period_month'] as String),
    amountDue: (m['amount_due'] as num).toDouble(),
    siblingDiscountApplied: (m['sibling_discount_applied'] as bool?) ?? false,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}

/// دفعة على استحقاق — قد يكون على استحقاق واحد أكثر من دفعة (سداد على
/// أقساط). كل صفّ هنا هو نفسه سجلّ الحركة: متى وبأي مبلغ.
class StudentPayment {
  const StudentPayment({
    required this.id,
    required this.dueId,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  final String id;
  final String dueId;
  final double amount;
  final DateTime paidAt;
  final String? note;

  factory StudentPayment.fromMap(Map<String, dynamic> m) => StudentPayment(
    id: m['id'] as String,
    dueId: m['due_id'] as String,
    amount: (m['amount'] as num).toDouble(),
    paidAt: DateTime.parse(m['paid_at'] as String).toLocal(),
    note: m['note'] as String?,
  );
}

/// حالة استحقاق شهر لطالب واحد — عرض مركَّب لشاشة المستحقات، يجمع
/// المبلغ المتوقَّع (من برامجه الحالية، حتى لو لم يُنشأ استحقاق فعلي بعد)
/// مع أي استحقاق ودفعات فعلية مسجَّلة لذلك الشهر.
class StudentDueOverview {
  const StudentDueOverview({
    required this.studentId,
    required this.fullName,
    required this.expectedAmount,
    required this.siblingDiscount,
    this.due,
    this.paidTotal = 0,
  });

  final String studentId;
  final String fullName;

  /// حالة خصم الإخوة الحالية على الطالب (students.sibling_discount) —
  /// منفصلة عن due.siblingDiscountApplied، وهي لقطة تخصّ استحقاقاً قديماً.
  final bool siblingDiscount;

  /// المبلغ المتوقَّع بحسب برامجه المسجَّل بها الآن وخصم الإخوة الحالي —
  /// يُستعمل لتوليد استحقاق جديد، وكمرجع إن لم يوجد استحقاق بعد.
  final double expectedAmount;

  final StudentDue? due;
  final double paidTotal;

  bool get hasDue => due != null;
  double get balance => (due?.amountDue ?? expectedAmount) - paidTotal;
  bool get isFullyPaid => hasDue && balance <= 0;
  bool get isPartiallyPaid => hasDue && paidTotal > 0 && balance > 0;
}
