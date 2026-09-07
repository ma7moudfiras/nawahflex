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
      final isPaid = await fetchPayoutStatus(id, month);
      list.add(
        TrainerPayroll(
          trainerId: id,
          fullName: name,
          hours: totals.$1,
          amount: totals.$2,
          isPaid: isPaid,
        ),
      );
    }
    return list;
  }

  Future<(double, double)> _computeMonth(
    String trainerId,
    DateTime month,
  ) async {
    final cohortRows = await Db.client
        .from('cohorts')
        .select('id')
        .eq('trainer_id', trainerId);
    final cohortIds = (cohortRows as List)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    if (cohortIds.isEmpty) return (0.0, 0.0);

    final start = _firstOfMonth(month);
    final end = _firstOfNextMonth(month);
    final sessions = await Db.client
        .from('class_sessions')
        .select('starts_at, ends_at, trainer_hourly_rate')
        .inFilter('cohort_id', cohortIds)
        .gte('session_date', _dateOnly(start))
        .lt('session_date', _dateOnly(end));

    var totalHours = 0.0;
    var totalAmount = 0.0;
    for (final s in (sessions as List).cast<Map<String, dynamic>>()) {
      final parsed = ClassSession.fromMap({
        ...s,
        'id': '',
        'cohort_id': '',
        'session_date': _dateOnly(start),
      });
      final h = parsed.hours;
      if (h == null) continue;
      totalHours += h;
      final rate = parsed.trainerHourlyRate;
      if (rate != null) totalAmount += h * rate;
    }
    return (totalHours, totalAmount);
  }

  Future<bool> fetchPayoutStatus(String trainerId, DateTime month) async {
    final row = await Db.client
        .from('trainer_payout_events')
        .select('is_paid')
        .eq('trainer_id', trainerId)
        .eq('period_month', _dateOnly(_firstOfMonth(month)))
        .order('changed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return (row?['is_paid'] as bool?) ?? false;
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
