import '../../core/supabase.dart';
import '../attendance/class_session.dart';
import 'trainer_payroll.dart';

/// مستحقات المدرّبين الشهرية — محسوبة من class_sessions فعلياً، لا من
/// سعر المدرّب الحالي، لأن كل حصة تحمل سعرها الخاص وقت تسجيلها.
class TrainerPayrollRepository {
  const TrainerPayrollRepository();

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);
  static DateTime _firstOfNextMonth(DateTime d) =>
      DateTime(d.year, d.month + 1);
  static String _dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  Future<List<TrainerPayroll>> fetchAll(DateTime month) async {
    final trainers = await Db.client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'trainer')
        .order('full_name');
    final list = <TrainerPayroll>[];
    for (final t in (trainers as List).cast<Map<String, dynamic>>()) {
      final id = t['id'] as String;
      final name = (t['full_name'] as String?)?.trim().isNotEmpty == true
          ? t['full_name'] as String
          : 'مدرّب';
      final totals = await _computeMonth(id, month);
      final lastEvent = await _fetchLastPayoutEvent(id, month);
      list.add(
        TrainerPayroll(
          trainerId: id,
          fullName: name,
          hours: totals.$1,
          amount: totals.$2,
          isPaid: lastEvent?.isPaid ?? false,
          statusChangedAt: lastEvent?.changedAt,
          statusChangedByName: lastEvent?.changedByName,
        ),
      );
    }
    return list;
  }

  /// المستحقات = ساعات كمدرّب أساسي لأفواجه + ساعات كمدرّب مساعد بلقاءات
  /// أفواج أخرى (كلٌّ بسعره الملتقَط وقت تلك الحصة تحديداً، لا سعره الحالي).
  Future<(double, double)> _computeMonth(
    String trainerId,
    DateTime month,
  ) async {
    final start = _firstOfMonth(month);
    final end = _firstOfNextMonth(month);
    var totalHours = 0.0;
    var totalAmount = 0.0;

    void accumulate(Map<String, dynamic> sessionMap, double? rate) {
      final parsed = ClassSession.fromMap({
        ...sessionMap,
        'id': '',
        'cohort_id': '',
        'trainer_hourly_rate': rate,
      });
      final h = parsed.hours;
      if (h == null) return;
      totalHours += h;
      final r = parsed.trainerHourlyRate;
      if (r != null) totalAmount += h * r;
    }

    final cohortRows = await Db.client
        .from('cohorts')
        .select('id')
        .eq('trainer_id', trainerId);
    final cohortIds = (cohortRows as List)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    if (cohortIds.isNotEmpty) {
      final sessions = await Db.client
          .from('class_sessions')
          .select('starts_at, ends_at, session_date, trainer_hourly_rate')
          .inFilter('cohort_id', cohortIds)
          .gte('session_date', _dateOnly(start))
          .lt('session_date', _dateOnly(end));
      for (final s in (sessions as List).cast<Map<String, dynamic>>()) {
        accumulate(s, (s['trainer_hourly_rate'] as num?)?.toDouble());
      }
    }

    final coRows = await Db.client
        .from('class_session_trainers')
        .select(
          'hourly_rate, class_sessions!inner(starts_at, ends_at, session_date)',
        )
        .eq('trainer_id', trainerId)
        .gte('class_sessions.session_date', _dateOnly(start))
        .lt('class_sessions.session_date', _dateOnly(end));
    for (final r in (coRows as List).cast<Map<String, dynamic>>()) {
      final cs = r['class_sessions'] as Map<String, dynamic>;
      accumulate(cs, (r['hourly_rate'] as num?)?.toDouble());
    }

    return (totalHours, totalAmount);
  }

  /// آخر حدث تسديد مسجَّل لهذا المدرّب بهذا الشهر — من ومتى ولأي حالة،
  /// الأحدث فقط (السجلّ الكامل يبقى مخزَّناً بلا استبدال).
  Future<({bool isPaid, DateTime changedAt, String? changedByName})?>
  _fetchLastPayoutEvent(String trainerId, DateTime month) async {
    final row = await Db.client
        .from('trainer_payout_events')
        .select(
          'is_paid, changed_at, profiles!trainer_payout_events_changed_by_fkey(full_name)',
        )
        .eq('trainer_id', trainerId)
        .eq('period_month', _dateOnly(_firstOfMonth(month)))
        .order('changed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return (
      isPaid: row['is_paid'] as bool,
      changedAt: DateTime.parse(row['changed_at'] as String).toLocal(),
      changedByName:
          (row['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
    );
  }

  Future<void> setPayoutStatus(
    String trainerId,
    DateTime month,
    bool isPaid,
  ) async {
    await Db.client.from('trainer_payout_events').insert({
      'trainer_id': trainerId,
      'period_month': _dateOnly(_firstOfMonth(month)),
      'is_paid': isPaid,
      'changed_by': Db.user?.id,
    });
  }
}
