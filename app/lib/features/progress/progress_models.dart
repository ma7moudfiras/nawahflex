/// نماذج محرّك التقدّم — تقابل جداول 0012_progress.sql حرفياً.
library;

/// النقاط والمستوى كما تحسبها القاعدة (`student_progress`).
class StudentProgress {
  const StudentProgress({
    required this.studentId,
    required this.points,
    required this.level,
    required this.levelTitle,
    required this.levelMinPoints,
    this.nextLevelPoints,
    this.sessionsAttended = 0,
    this.sessionsTotal = 0,
    this.badgesCount = 0,
    this.projectsCount = 0,
  });

  /// طالب بلا أي نشاط بعد — المستوى الأول.
  const StudentProgress.empty(this.studentId)
      : points = 0,
        level = 1,
        levelTitle = 'نواة',
        levelMinPoints = 0,
        nextLevelPoints = null,
        sessionsAttended = 0,
        sessionsTotal = 0,
        badgesCount = 0,
        projectsCount = 0;

  final String studentId;
  final int points;
  final int level;
  final String levelTitle;
  final int levelMinPoints;

  /// عتبة المستوى التالي؛ فارغة في المستوى الأخير.
  final int? nextLevelPoints;
  final int sessionsAttended;
  final int sessionsTotal;
  final int badgesCount;
  final int projectsCount;

  bool get isMaxLevel => nextLevelPoints == null;

  /// نسبة التقدّم داخل المستوى الحالي (٠–١).
  double get levelFraction {
    final next = nextLevelPoints;
    if (next == null) return 1;
    final span = next - levelMinPoints;
    if (span <= 0) return 1;
    return ((points - levelMinPoints) / span).clamp(0.0, 1.0);
  }

  int get pointsToNext => isMaxLevel ? 0 : nextLevelPoints! - points;

  /// نسبة الحضور (حاضر أو متأخّر من كل الحصص المسجَّلة)، أو فارغة بلا سجلّ.
  int? get attendanceRate =>
      sessionsTotal == 0 ? null : (sessionsAttended / sessionsTotal * 100).round();

  factory StudentProgress.fromMap(Map<String, dynamic> m) => StudentProgress(
        studentId: m['student_id'] as String,
        points: (m['points'] as num).toInt(),
        level: (m['level'] as num).toInt(),
        levelTitle: m['level_title'] as String,
        levelMinPoints: (m['level_min_points'] as num).toInt(),
        nextLevelPoints: (m['next_level_points'] as num?)?.toInt(),
        sessionsAttended: (m['sessions_attended'] as num?)?.toInt() ?? 0,
        sessionsTotal: (m['sessions_total'] as num?)?.toInt() ?? 0,
        badgesCount: (m['badges_count'] as num?)?.toInt() ?? 0,
        projectsCount: (m['projects_count'] as num?)?.toInt() ?? 0,
      );
}

/// شارة في الكتالوج.
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    this.programId,
    this.isActive = true,
  });

  final String id;
  final String key;
  final String title;
  final String description;
  final String icon;
  final int points;
  final String? programId;
  final bool isActive;

  factory BadgeDef.fromMap(Map<String, dynamic> m) => BadgeDef(
        id: m['id'] as String,
        key: m['key'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        icon: (m['icon'] as String?) ?? 'star',
        points: (m['points'] as num).toInt(),
        programId: m['program_id'] as String?,
        isActive: (m['is_active'] as bool?) ?? true,
      );
}

/// شارة نالها طالب.
class EarnedBadge {
  const EarnedBadge({
    required this.id,
    required this.badgeId,
    required this.awardedAt,
    this.awardedBy,
    this.note,
  });

  final String id;
  final String badgeId;
  final DateTime awardedAt;
  final String? awardedBy;
  final String? note;

  factory EarnedBadge.fromMap(Map<String, dynamic> m) => EarnedBadge(
        id: m['id'] as String,
        badgeId: m['badge_id'] as String,
        awardedAt: DateTime.parse(m['awarded_at'] as String).toLocal(),
        awardedBy: m['awarded_by'] as String?,
        note: m['note'] as String?,
      );
}

/// مهارة في برنامج.
class Skill {
  const Skill({
    required this.id,
    required this.programId,
    required this.title,
    this.description,
    this.sortOrder = 0,
  });

  final String id;
  final String programId;
  final String title;
  final String? description;
  final int sortOrder;

  factory Skill.fromMap(Map<String, dynamic> m) => Skill(
        id: m['id'] as String,
        programId: m['program_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// درجات المهارة الأربع — كلمات يفهمها ولي الأمر، لا علامات مدرسية.
class SkillLevel {
  SkillLevel._();
  static const max = 4;
  static const labels = <int, String>{
    1: 'مبتدئ',
    2: 'متقدّم',
    3: 'متمكّن',
    4: 'خبير',
  };
  static String label(int level) => labels[level] ?? '—';
}

/// ملاحظة المدرّب عن الطالب.
class StudentNote {
  const StudentNote({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.visibleToGuardian,
    this.authorId,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final bool visibleToGuardian;
  final String? authorId;

  factory StudentNote.fromMap(Map<String, dynamic> m) => StudentNote(
        id: m['id'] as String,
        body: m['body'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        visibleToGuardian: (m['visible_to_guardian'] as bool?) ?? true,
        authorId: m['author_id'] as String?,
      );
}
