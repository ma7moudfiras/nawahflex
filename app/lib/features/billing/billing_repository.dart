import '../../core/supabase.dart';
import 'student_due.dart';

/// مستحقات الطلاب — استحقاق شهري (لقطة مبلغ) ودفعات عليه، وخصم الإخوة.
/// كل شيء هنا إدارة فقط (RLS من 0007_billing_and_sessions.sql).
class BillingRepository {
  const BillingRepository();

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);
  static String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  /// المبلغ الشهري المتوقَّع لطالب بحسب برامجه المسجَّل بها الآن وخصم
  /// الإخوة الحالي — لا يقرأ أي استحقاق مخزَّن، هذا حساب حيّ للتوليد.
  Future<double> computeExpectedAmount(String studentId) async {
    final student = await Db.client
        .from('students')
        .select('sibling_discount')
        .eq('id', studentId)
        .single();
    final sibling = (student['sibling_discount'] as bool?) ?? false;

    final rows = await Db.client
        .from('student_programs')
        .select('programs(price, sibling_price)')
        .eq('student_id', studentId);

    var total = 0.0;
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final program = r['programs'] as Map<String, dynamic>?;
      if (program == null) continue;
      final price = (program['price'] as num?)?.toInt() ?? 0;
      final siblingPrice = (program['sibling_price'] as num?)?.toInt();
      total += (sibling && siblingPrice != null) ? siblingPrice : price;
    }
    return total;
  }

  /// نظرة عامة على كل الطلاب النشطين لشهر معيّن — المبلغ المتوقَّع، وأي
  /// استحقاق ودفعات فعلية مسجَّلة له.
  Future<List<StudentDueOverview>> fetchOverview(DateTime month) async {
    final period = _firstOfMonth(month);

    final students = await Db.client
        .from('students')
        .select(
          'id, full_name, sibling_discount, student_programs(programs(price, sibling_price))',
        )
        .eq('is_active', true)
        .order('full_name');

    final dues = await Db.client
        .from('student_dues')
        .select('*')
        .eq('period_month', _dateOnly(period));
    final duesByStudent = {
      for (final d in (dues as List).cast<Map<String, dynamic>>())
        d['student_id'] as String: StudentDue.fromMap(d),
    };

    final dueIds = duesByStudent.values.map((d) => d.id).toList();
    var paidByDue = <String, double>{};
    if (dueIds.isNotEmpty) {
      final payments = await Db.client
          .from('student_payments')
          .select('due_id, amount')
          .inFilter('due_id', dueIds);
      for (final p in (payments as List).cast<Map<String, dynamic>>()) {
        final dueId = p['due_id'] as String;
        paidByDue[dueId] =
            (paidByDue[dueId] ?? 0) + (p['amount'] as num).toDouble();
      }
    }

    return (students as List).cast<Map<String, dynamic>>().map((s) {
      final sibling = (s['sibling_discount'] as bool?) ?? false;
      final programs = (s['student_programs'] as List? ?? [])
          .map(
            (sp) =>
                (sp as Map<String, dynamic>)['programs']
                    as Map<String, dynamic>?,
          )
          .whereType<Map<String, dynamic>>();
      var expected = 0.0;
      for (final p in programs) {
        final price = (p['price'] as num?)?.toInt() ?? 0;
        final siblingPrice = (p['sibling_price'] as num?)?.toInt();
        expected += (sibling && siblingPrice != null) ? siblingPrice : price;
      }
      final due = duesByStudent[s['id']];
      return StudentDueOverview(
        studentId: s['id'] as String,
        fullName: (s['full_name'] as String?) ?? '',
        expectedAmount: expected,
        siblingDiscount: sibling,
        due: due,
        paidTotal: due == null ? 0 : (paidByDue[due.id] ?? 0),
      );
    }).toList();
  }

  Future<List<StudentPayment>> fetchPayments(String dueId) async {
    final rows = await Db.client
        .from('student_payments')
        .select('*')
        .eq('due_id', dueId)
        .order('paid_at');
    return (rows as List)
        .map((r) => StudentPayment.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// ينشئ استحقاق الشهر لطالب إن لم يوجد بعد — يلتقط المبلغ المتوقَّع
  /// حالياً كلقطة ثابتة. إن كان موجوداً أصلاً يرجعه كما هو بلا تعديل.
  Future<StudentDue> ensureDue(String studentId, DateTime month) async {
    final period = _firstOfMonth(month);
    final existing = await Db.client
        .from('student_dues')
        .select('*')
        .eq('student_id', studentId)
        .eq('period_month', _dateOnly(period))
        .maybeSingle();
    if (existing != null) return StudentDue.fromMap(existing);

    final student = await Db.client
        .from('students')
        .select('sibling_discount')
        .eq('id', studentId)
        .single();
    final sibling = (student['sibling_discount'] as bool?) ?? false;
    final amount = await computeExpectedAmount(studentId);

    final row = await Db.client
        .from('student_dues')
        .insert({
          'student_id': studentId,
          'period_month': _dateOnly(period),
          'amount_due': amount,
          'sibling_discount_applied': sibling,
          'created_by': Db.user?.id,
        })
        .select('*')
        .single();
    return StudentDue.fromMap(row);
  }

  Future<void> recordPayment({
    required String dueId,
    required double amount,
    String? note,
  }) async {
    await Db.client.from('student_payments').insert({
      'due_id': dueId,
      'amount': amount,
      'note': note,
      'recorded_by': Db.user?.id,
    });
  }

  Future<void> setSiblingDiscount(String studentId, bool enabled) async {
    await Db.client
        .from('students')
        .update({'sibling_discount': enabled})
        .eq('id', studentId);
    await Db.client.from('student_discount_log').insert({
      'student_id': studentId,
      'enabled': enabled,
      'changed_by': Db.user?.id,
    });
  }

  /// عدد الطلاب غير المسدَّدين بالكامل لشهر معيّن — لبطاقة الشاشة الرئيسية.
  Future<int> countUnpaid(DateTime month) async {
    final overview = await fetchOverview(month);
    return overview.where((o) => !o.isFullyPaid).length;
  }
}
