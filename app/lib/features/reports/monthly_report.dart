import '../attendance/attendance_status.dart';
import '../progress/progress_models.dart';

typedef AttendanceDay = ({DateTime date, String status});

/// تقرير الشهر لولي الأمر: ما حدث في شهر واحد، من بيانات الملف نفسها.
///
/// تجميع خالص بلا قاعدة ولا واجهة — فيُختبر وحده. لا يضمّ إلا ما يجوز
/// لولي الأمر رؤيته: الملاحظات المعلَّمة «للأهل» فقط، ولو ولّدته الإدارة.
class MonthlyReport {
  const MonthlyReport({
    required this.studentName,
    required this.month,
    required this.level,
    required this.levelTitle,
    required this.points,
    required this.pointsToNext,
    required this.attendance,
    required this.badges,
    required this.projects,
    required this.skills,
    required this.notes,
  });

  final String studentName;

  /// أول يوم في الشهر.
  final DateTime month;
  final int level;
  final String levelTitle;
  final int points;

  /// null في المستوى الأعلى.
  final int? pointsToNext;
  final List<AttendanceDay> attendance;
  final List<({String title, DateTime at})> badges;
  final List<({String title, int? rating, DateTime at})> projects;

  /// المهارات بدرجتها الحالية (لقطة لا تغيّرات الشهر).
  final List<({String title, int? level})> skills;
  final List<({String body, DateTime at})> notes;

  int get attended =>
      attendance.where((a) => a.status == AttendanceStatus.present || a.status == AttendanceStatus.late).length;

  /// حاضر أو متأخّر من حصص الشهر — نفس تعريف الملف.
  int? get attendanceRate => attendance.isEmpty ? null : (attended / attendance.length * 100).round();

  static DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

  /// آخر [count] أشهر، الأحدث أولاً — ما يختار منه المستخدم.
  static List<DateTime> recentMonths(DateTime now, {int count = 6}) =>
      [for (var i = 0; i < count; i++) DateTime(now.year, now.month - i)];

  factory MonthlyReport.build({
    required DateTime month,
    required String studentName,
    required StudentProgress progress,
    required List<AttendanceDay> attendance,
    required List<BadgeDef> catalog,
    required List<EarnedBadge> earned,
    required List<StudentProject> projects,
    required List<Skill> skills,
    required Map<String, int> skillLevels,
    required List<StudentNote> notes,
  }) {
    final m = monthOf(month);
    bool inMonth(DateTime d) => d.year == m.year && d.month == m.month;
    final titles = {for (final b in catalog) b.id: b.title};

    return MonthlyReport(
      studentName: studentName,
      month: m,
      level: progress.level,
      levelTitle: progress.levelTitle,
      points: progress.points,
      pointsToNext: progress.isMaxLevel ? null : progress.pointsToNext,
      attendance: attendance.where((a) => inMonth(a.date)).toList()..sort((a, b) => a.date.compareTo(b.date)),
      badges: [
        for (final e in earned.where((e) => inMonth(e.awardedAt)))
          if (titles[e.badgeId] != null) (title: titles[e.badgeId]!, at: e.awardedAt),
      ]..sort((a, b) => a.at.compareTo(b.at)),
      projects: [
        for (final p in projects.where((p) => inMonth(p.createdAt))) (title: p.title, rating: p.rating, at: p.createdAt),
      ]..sort((a, b) => a.at.compareTo(b.at)),
      skills: [for (final s in skills) (title: s.title, level: skillLevels[s.id])],
      notes: [
        for (final n in notes.where((n) => n.visibleToGuardian && inMonth(n.createdAt))) (body: n.body, at: n.createdAt),
      ]..sort((a, b) => a.at.compareTo(b.at)),
    );
  }
}
