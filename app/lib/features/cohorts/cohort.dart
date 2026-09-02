/// فوج — يقابل جدول public.cohorts. يربط برنامجاً بمدرّب وجدول زمني،
/// والطلاب يُسجَّلون به عبر public.enrollments (لا مباشرة هنا).
class Cohort {
  const Cohort({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.programId,
    this.programTitle,
    this.trainerId,
    this.trainerName,
    this.scheduleLabel,
    this.startsAt,
    this.endsAt,
    this.capacity,
  });

  final String id;
  final String name;
  final String? programId;
  final String? programTitle;
  final String? trainerId;
  final String? trainerName;
  final String? scheduleLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? capacity;
  final bool isActive;
  final DateTime createdAt;

  factory Cohort.fromMap(Map<String, dynamic> m) => Cohort(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        programId: m['program_id'] as String?,
        programTitle: (m['programs'] as Map<String, dynamic>?)?['title'] as String?,
        trainerId: m['trainer_id'] as String?,
        trainerName: (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
        scheduleLabel: m['schedule_label'] as String?,
        startsAt: m['starts_at'] == null ? null : DateTime.parse(m['starts_at'] as String),
        endsAt: m['ends_at'] == null ? null : DateTime.parse(m['ends_at'] as String),
        capacity: (m['capacity'] as num?)?.toInt(),
        isActive: (m['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        if (programId != null) 'program_id': programId,
        if (trainerId != null) 'trainer_id': trainerId,
        if (scheduleLabel != null && scheduleLabel!.isNotEmpty) 'schedule_label': scheduleLabel,
        if (startsAt != null) 'starts_at': startsAt!.toIso8601String().split('T').first,
        if (endsAt != null) 'ends_at': endsAt!.toIso8601String().split('T').first,
        if (capacity != null) 'capacity': capacity,
        'is_active': isActive,
      };
}
