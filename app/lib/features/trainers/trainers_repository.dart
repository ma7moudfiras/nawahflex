import '../../core/supabase.dart';
import '../auth/profile.dart';
import '../cohorts/cohort.dart';
import 'trainer.dart';

/// قراءة وكتابة سِيَر المدرّبين (public.trainers) — محتوى تعريفي يُعرض
/// بالموقع، منفصل عن حسابات الدخول (public.profiles). الربط بينهما
/// اختياري عبر profile_id.
class TrainersRepository {
  const TrainersRepository();

  static const _cols = 'id, profile_id, full_name, title, bio, is_published, created_at';

  Future<List<Trainer>> fetch() async {
    final rows = await Db.client.from('trainers').select(_cols).order('full_name');
    return (rows as List).map((r) => Trainer.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<int> count() async {
    final rows = await Db.client.from('trainers').select('id');
    return (rows as List).length;
  }

  Future<String> create(Trainer t) async {
    final row = await Db.client.from('trainers').insert(t.toInsertMap()).select('id').single();
    return row['id'] as String;
  }

  Future<void> update(String id, Trainer t) async {
    await Db.client.from('trainers').update(t.toInsertMap()).eq('id', id);
  }

  /// حسابات دخول بصلاحية مدرّب متاحة للربط بسيرة — تستثني الحسابات
  /// المربوطة بسيرة أخرى مسبقاً، لكن تُبقي حساب السيرة الحالية نفسها
  /// (عند التعديل) ضمن الخيارات حتى تظهر مُحدَّدة.
  Future<List<Profile>> fetchAvailableTrainerAccounts({String? excludingTrainerId}) async {
    final profiles =
        await Db.client.from('profiles').select('id, full_name, role').eq('role', 'trainer').order('full_name');
    var linkedQuery = Db.client.from('trainers').select('profile_id');
    final linkedRows =
        excludingTrainerId == null ? await linkedQuery : await linkedQuery.neq('id', excludingTrainerId);
    final linkedIds = (linkedRows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['profile_id'] as String?)
        .whereType<String>()
        .toSet();
    return (profiles as List)
        .cast<Map<String, dynamic>>()
        .map(Profile.fromMap)
        .where((p) => !linkedIds.contains(p.id))
        .toList();
  }

  /// سعر ساعة المدرّب الحالي — خاص تماماً (جدول trainer_pay_rates، ليس
  /// public.trainers) حتى لا يظهر بالموقع أبداً. يُقرأ فقط عند وجود حساب
  /// دخول مرتبط، فالسعر بلا حساب لا معنى له (لا حصص تُسجَّل بلا حساب).
  Future<double?> fetchHourlyRate(String profileId) async {
    final row = await Db.client
        .from('trainer_pay_rates')
        .select('hourly_rate')
        .eq('profile_id', profileId)
        .maybeSingle();
    return row == null ? null : (row['hourly_rate'] as num).toDouble();
  }

  /// يحدّث سعر الساعة الحالي — لا يمسّ أي حصة سُجِّلت سابقاً، لأن كل حصة
  /// تحمل لقطتها الخاصة من السعر وقت تسجيلها (class_sessions.trainer_hourly_rate).
  Future<void> setHourlyRate(String profileId, double rate) async {
    await Db.client.from('trainer_pay_rates').upsert({
      'profile_id': profileId,
      'hourly_rate': rate,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// الأفواج التي يتولاها هذا الحساب حالياً — عرض فقط؛ التعيين نفسه يبقى
  /// من شاشة الأفواج (مصدر حقيقة واحد لـ cohorts.trainer_id).
  Future<List<Cohort>> fetchResponsibleCohorts(String profileId) async {
    final rows = await Db.client
        .from('cohorts')
        .select('id, name, program_id, trainer_id, schedule_label, starts_at, ends_at, capacity, is_active, created_at')
        .eq('trainer_id', profileId)
        .order('name');
    return (rows as List).map((r) => Cohort.fromMap(r as Map<String, dynamic>)).toList();
  }
}
