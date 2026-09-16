import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../core/supabase.dart';
import '../../shared/adaptive.dart';
import '../auth/profile.dart';
import '../cohorts/cohort.dart';
import '../cohorts/cohorts_repository.dart';
import 'attendance_repository.dart';
import 'attendance_status.dart';
import 'class_session.dart';

/// شاشة اللقاءات — يراها المدرّب والإدارة. تعرض اللقاءات السابقة (مجمَّعة
/// بالسنين) افتراضياً عند فتحها، وزر عائم لتسجيل لقاء جديد. RLS تُقيّد
/// ما يظهر تلقائياً: المدرّب يرى أفواجه، وأفواجاً ساعد بلقاء واحد فيها
/// على الأقل (قراءة فقط)، ولا يرى من لقاءات تلك الأفواج الأخرى إلا ما
/// شارك هو به تحديداً. فلتر اختيار المدرّب فوق القائمة للإدارة وحدها.
///
/// نفس الشاشة تماماً للإدارة والمدرّب — الإضافة الوحيدة للإدارة فلتر
/// اختيار المدرّب (مصدر حقيقة واحد لمنطق التسجيل والعرض).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _cohortsRepo = const CohortsRepository();
  final _attendanceRepo = const AttendanceRepository();

  List<Cohort> _cohorts = [];
  List<Profile> _trainers = [];
  String? _trainerFilter;
  Cohort? _selectedCohort;
  List<ClassSession> _pastSessions = [];

  bool _loadingCohorts = true;
  bool _loadingHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCohorts();
  }

  List<Cohort> get _visibleCohorts => _trainerFilter == null
      ? _cohorts
      : _cohorts.where((c) => c.trainerId == _trainerFilter).toList();

  /// الأفواج التي يقدر المستخدم الحالي يسجّل لها لقاءً جديداً — الإدارة
  /// كل الأفواج، والمدرّب أفواجه هو فقط (لا الأفواج التي يراها كمدرّب
  /// مساعد فقط — تلك للعرض لا للتسجيل).
  List<Cohort> get _writableCohorts => widget.isAdmin
      ? _cohorts
      : _cohorts.where((c) => c.trainerId == Db.user?.id).toList();

  /// قائمة المدرّبين لفلتر الإدارة — مشتقّة من الأفواج المحمَّلة نفسها.
  List<MapEntry<String, String>> get _trainerOptions {
    final map = <String, String>{};
    for (final c in _cohorts) {
      if (c.trainerId != null) map[c.trainerId!] = c.trainerName ?? '—';
    }
    final list = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  Future<void> _loadCohorts() async {
    setState(() {
      _loadingCohorts = true;
      _error = null;
    });
    try {
      final cohorts = await _cohortsRepo.fetch();
      final trainers = widget.isAdmin
          ? await _cohortsRepo.fetchTrainers()
          : <Profile>[];
      if (!mounted) return;
      setState(() {
        _cohorts = cohorts;
        _trainers = trainers;
        _selectedCohort = _visibleCohorts.isEmpty
            ? null
            : _visibleCohorts.first;
        _loadingCohorts = false;
      });
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCohorts = false;
        _error = 'تعذّر تحميل الأفواج. تحقّق من اتصالك ثم أعد المحاولة.';
      });
    }
  }

  void _onTrainerFilterChanged(String? trainerId) {
    setState(() {
      _trainerFilter = trainerId;
      _selectedCohort = _visibleCohorts.isEmpty ? null : _visibleCohorts.first;
    });
    _loadHistory();
  }

  void _onCohortChanged(Cohort? c) {
    setState(() => _selectedCohort = c);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final cohort = _selectedCohort;
    if (cohort == null) {
      setState(() => _pastSessions = []);
      return;
    }
    setState(() => _loadingHistory = true);
    try {
      final sessions = await _attendanceRepo.fetchPastSessions(cohort.id);
      if (!mounted) return;
      setState(() {
        _pastSessions = sessions;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحميل اللقاءات السابقة')),
      );
    }
  }

  Map<int, List<ClassSession>> get _sessionsByYear {
    final map = <int, List<ClassSession>>{};
    for (final s in _pastSessions) {
      map.putIfAbsent(s.sessionDate.year, () => []).add(s);
    }
    return map;
  }

  Future<void> _openMeetingForm({ClassSession? existing}) async {
    final writable = _writableCohorts;
    if (existing == null && writable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد فوج تديره لتسجيل لقاء له.')),
      );
      return;
    }
    // عند التعديل، تأكّد أن فوج اللقاء نفسه ضمن القائمة حتى لو المستخدم لا
    // يملكه (مدرّب مساعد يفتح "تعديل" من شاشة التفاصيل) — العرض يحتاجه،
    // والحفظ الفعلي يبقى محكوماً بصلاحيات RLS الحقيقية بغضّ النظر.
    final formCohorts =
        existing == null || writable.any((c) => c.id == existing.cohortId)
        ? writable
        : [
            ...writable,
            _cohorts.firstWhere(
              (c) => c.id == existing.cohortId,
              orElse: () => _cohorts.first,
            ),
          ];
    final startCohortId =
        existing?.cohortId ??
        (_selectedCohort != null &&
                writable.any((c) => c.id == _selectedCohort!.id)
            ? _selectedCohort!.id
            : writable.first.id);

    final allTrainers = _trainers.isNotEmpty
        ? _trainers
        : await _cohortsRepo.fetchTrainers();
    if (!mounted) return;
    final form = _MeetingForm(
      cohorts: formCohorts,
      allTrainers: allTrainers,
      initial: existing,
      initialCohortId: startCohortId,
      repo: _attendanceRepo,
    );

    if (context.isWide) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
            child: form,
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.95, child: form),
      );
    }
    await _loadHistory();
  }

  /// يفتح لقاءً ماضياً بتفاصيله من قائمة السجلّ.
  Future<void> _openPastSession(ClassSession session) async {
    final cohort = _cohorts.firstWhere(
      (c) => c.id == session.cohortId,
      orElse: () => _selectedCohort!,
    );
    try {
      final roster = await _attendanceRepo.fetchRoster(cohort.id);
      final statuses = await _attendanceRepo.fetchStatuses(
        cohort.id,
        session.sessionDate,
      );
      final coTrainers = await _attendanceRepo.fetchCoTrainers(session.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _MeetingDetailScreen(
            cohort: cohort,
            session: session,
            roster: roster,
            statuses: statuses,
            coTrainers: coTrainers,
            onEdit: () {
              Navigator.of(context).pop();
              _openMeetingForm(existing: session);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذّر فتح تفاصيل اللقاء')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCohorts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Empty(
        icon: Icons.wifi_off,
        title: 'تعذّر التحميل',
        subtitle: _error!,
        action: FilledButton.tonal(
          onPressed: _loadCohorts,
          child: const Text('إعادة المحاولة'),
        ),
      );
    }

    if (_cohorts.isEmpty) {
      return const _Empty(
        icon: Icons.groups_2_outlined,
        title: 'لا يوجد فوج مُسنَد إليك',
        subtitle: 'تواصل مع إدارة الأكاديمية لإسنادك إلى فوج.',
      );
    }

    final cohorts = _visibleCohorts;
    final byYear = _sessionsByYear;
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMeetingForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة لقاء'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(NawahSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isAdmin && _trainerOptions.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _trainerFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المدرّب'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('كل المدرّبين'),
                    ),
                    ..._trainerOptions.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: _onTrainerFilterChanged,
                ),
                const SizedBox(height: NawahSpacing.s3),
              ],
              DropdownButton<Cohort>(
                value: cohorts.contains(_selectedCohort)
                    ? _selectedCohort
                    : null,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                hint: const Text('اختر فوجاً'),
                items: cohorts
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _onCohortChanged,
              ),
              const SizedBox(height: NawahSpacing.s4),

              if (_selectedCohort == null)
                const _Empty(
                  icon: Icons.groups_2_outlined,
                  title: 'اختر فوجاً',
                  subtitle: 'اختر فوجاً من القائمة أعلاه لعرض لقاءاته.',
                )
              else if (_loadingHistory)
                const Padding(
                  padding: EdgeInsets.all(NawahSpacing.s6),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_pastSessions.isEmpty)
                const _Empty(
                  icon: Icons.event_busy_outlined,
                  title: 'لا يوجد لقاءات مسجَّلة بعد بهذا الفوج',
                  subtitle: 'اضغط زر "إضافة لقاء" لتسجيل أول لقاء.',
                )
              else
                for (final year in years) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: NawahSpacing.s2,
                    ),
                    child: Text(
                      '$year',
                      style: const TextStyle(
                        fontFamily: NawahFonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: NawahColors.textSoft,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: NawahColors.card,
                      borderRadius: BorderRadius.circular(NawahRadius.md),
                      border: Border.all(color: NawahColors.border),
                    ),
                    child: Column(
                      children: [
                        for (final s in byYear[year]!) ...[
                          ListTile(
                            onTap: () => _openPastSession(s),
                            leading: const Icon(
                              Icons.event_note_outlined,
                              color: NawahColors.primary,
                            ),
                            title: Text(
                              '${s.sessionDate.year}/${s.sessionDate.month}/${s.sessionDate.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: NawahColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              s.startsAt == null
                                  ? (s.notes ?? 'بلا ملاحظات')
                                  : '${_fmt(s.startsAt)} – ${_fmt(s.endsAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.chevron_left,
                              color: NawahColors.textMuted,
                            ),
                          ),
                          if (s != byYear[year]!.last) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: NawahSpacing.s4),
                ],
              const SizedBox(height: NawahSpacing.s6),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(TimeOfDay? t) => t == null
      ? '—'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// نموذج تسجيل/تعديل لقاء — يظهر كحوار على العريض وكـ bottom sheet على
/// الجوّال، ويبقى مفتوحاً بعد أي تعديل (تعليم حضور مثلاً يُحفَظ فوراً)
/// حتى يغلقه المستخدم بنفسه، تماماً كبقية نماذج الحضور بهذا التطبيق.
class _MeetingForm extends StatefulWidget {
  const _MeetingForm({
    required this.cohorts,
    required this.allTrainers,
    required this.initialCohortId,
    required this.repo,
    this.initial,
  });

  final List<Cohort> cohorts;
  final List<Profile> allTrainers;
  final String initialCohortId;
  final ClassSession? initial;
  final AttendanceRepository repo;

  @override
  State<_MeetingForm> createState() => _MeetingFormState();
}

class _MeetingFormState extends State<_MeetingForm> {
  final _notes = TextEditingController();
  late String _cohortId;
  late DateTime _date;
  TimeOfDay? _startsAt;
  TimeOfDay? _endsAt;
  Set<String> _coTrainerIds = {};
  List<RosterEntry> _roster = [];
  Map<String, String> _statuses = {};
  String? _sessionId;
  bool _savingSession = false;
  bool _loadingRoster = true;

  bool get _editing => widget.initial != null;

  Cohort get _cohort => widget.cohorts.firstWhere(
    (c) => c.id == _cohortId,
    orElse: () => widget.cohorts.first,
  );

  List<Profile> get _coTrainerOptions =>
      widget.allTrainers.where((p) => p.id != _cohort.trainerId).toList();

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _cohortId = s?.cohortId ?? widget.initialCohortId;
    _date = s?.sessionDate ?? DateTime.now();
    _startsAt = s?.startsAt;
    _endsAt = s?.endsAt;
    _notes.text = s?.notes ?? '';
    _sessionId = s?.id;
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingRoster = true);
    try {
      final roster = await widget.repo.fetchRoster(_cohortId);
      final statuses = await widget.repo.fetchStatuses(_cohortId, _date);
      final coTrainers = _sessionId == null
          ? const <SessionCoTrainer>[]
          : await widget.repo.fetchCoTrainers(_sessionId!);
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _statuses = statuses;
        _coTrainerIds = coTrainers.map((t) => t.trainerId).toSet();
        _loadingRoster = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoster = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذّر تحميل قائمة الطلاب')));
    }
  }

  void _onCohortChanged(String? id) {
    if (id == null || _editing) return;
    setState(() {
      _cohortId = id;
      _sessionId = null;
      _statuses = {};
      _coTrainerIds = {};
    });
    _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'تاريخ اللقاء',
    );
    if (picked != null) {
      setState(() => _date = picked);
      await widget.repo.fetchSession(_cohortId, _date).then((s) {
        if (mounted) setState(() => _sessionId = s?.id);
      });
      await _load();
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startsAt : _endsAt) ?? TimeOfDay.now(),
      helpText: isStart ? 'وقت بداية اللقاء' : 'وقت نهاية اللقاء',
    );
    if (picked != null) {
      setState(() => isStart ? _startsAt = picked : _endsAt = picked);
    }
  }

  Future<String?> _ensureSessionId() async {
    if (_sessionId != null) return _sessionId;
    final id = await widget.repo.saveSession(
      cohortId: _cohortId,
      date: _date,
      startsAt: _startsAt,
      endsAt: _endsAt,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (mounted) setState(() => _sessionId = id);
    return id;
  }

  Future<void> _saveDetails() async {
    setState(() => _savingSession = true);
    try {
      final id = await widget.repo.saveSession(
        cohortId: _cohortId,
        date: _date,
        startsAt: _startsAt,
        endsAt: _endsAt,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      await widget.repo.setCoTrainers(id, _coTrainerIds.toList());
      if (!mounted) return;
      setState(() => _sessionId = id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ تفاصيل اللقاء')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر حفظ تفاصيل اللقاء — حاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSession = false);
    }
  }

  Future<void> _mark(String studentId, String status) async {
    final previous = _statuses[studentId];
    setState(() => _statuses = {..._statuses, studentId: status});
    try {
      final sessionId = await _ensureSessionId();
      await widget.repo.mark(
        cohortId: _cohortId,
        studentId: studentId,
        date: _date,
        status: status,
        sessionId: sessionId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final m = {..._statuses};
        if (previous == null) {
          m.remove(studentId);
        } else {
          m[studentId] = previous;
        }
        _statuses = m;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ الحضور — حاول مجدداً.')),
      );
    }
  }

  Future<void> _openAddStudent() async {
    final added = await showDialog<RosterEntry>(
      context: context,
      builder: (_) => _AddStudentDialog(repo: widget.repo, cohortId: _cohortId),
    );
    if (added == null) return;
    try {
      await widget.repo.addStudentToCohort(_cohortId, added.studentId);
      if (mounted) {
        setState(
          () => _roster = [..._roster, added]
            ..sort((a, b) => a.fullName.compareTo(b.fullName)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذّر إضافة الطالب — تأكّد من صلاحيتك وحاول مجدداً.',
            ),
          ),
        );
      }
    }
  }

  String _fmtTime(TimeOfDay? t) => t == null ? '—' : t.format(context);

  @override
  Widget build(BuildContext context) {
    final duration = ClassSession(
      id: '',
      cohortId: '',
      sessionDate: _date,
      startsAt: _startsAt,
      endsAt: _endsAt,
    ).hours;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: NawahSpacing.s5,
        right: NawahSpacing.s5,
        top: NawahSpacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editing ? 'تعديل لقاء' : 'لقاء جديد',
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: NawahColors.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: NawahSpacing.s3),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: NawahSpacing.s3),
                      child: Text(
                        'الفوج: ${_cohort.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: NawahColors.ink,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: NawahSpacing.s3),
                      child: DropdownButtonFormField<String>(
                        initialValue: _cohortId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'الفوج'),
                        items: widget.cohorts
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: _onCohortChanged,
                      ),
                    ),

                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('${_date.year}/${_date.month}/${_date.day}'),
                  ),
                  const SizedBox(height: NawahSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(isStart: true),
                          icon: const Icon(Icons.schedule_outlined, size: 18),
                          label: Text('من: ${_fmtTime(_startsAt)}'),
                        ),
                      ),
                      const SizedBox(width: NawahSpacing.s3),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(isStart: false),
                          icon: const Icon(Icons.schedule_outlined, size: 18),
                          label: Text('إلى: ${_fmtTime(_endsAt)}'),
                        ),
                      ),
                    ],
                  ),
                  if (duration != null)
                    Padding(
                      padding: const EdgeInsets.only(top: NawahSpacing.s2),
                      child: Text(
                        'المدّة: ${duration.toStringAsFixed(duration == duration.roundToDouble() ? 0 : 1)} ساعة',
                        style: const TextStyle(
                          color: NawahColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: NawahSpacing.s3),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ماذا جرى بهذا اللقاء؟ (اختياري)',
                    ),
                  ),

                  if (_coTrainerOptions.isNotEmpty) ...[
                    const SizedBox(height: NawahSpacing.s4),
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'مدرّب مساعد بهذا اللقاء (اختياري)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: NawahColors.textSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: NawahSpacing.s2),
                    Wrap(
                      spacing: NawahSpacing.s2,
                      runSpacing: NawahSpacing.s2,
                      children: _coTrainerOptions.map((p) {
                        final selected = _coTrainerIds.contains(p.id);
                        return FilterChip(
                          label: Text(p.displayName),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            final ids = {..._coTrainerIds};
                            if (v) {
                              ids.add(p.id);
                            } else {
                              ids.remove(p.id);
                            }
                            _coTrainerIds = ids;
                          }),
                          selectedColor: NawahColors.primarySoft,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: NawahSpacing.s3),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: _savingSession ? null : _saveDetails,
                      icon: _savingSession
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('حفظ تفاصيل اللقاء'),
                    ),
                  ),
                  const SizedBox(height: NawahSpacing.s5),

                  Row(
                    children: [
                      const Text(
                        'الحضور',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: NawahColors.ink,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _openAddStudent,
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 18,
                        ),
                        label: const Text('إضافة طالب'),
                      ),
                    ],
                  ),
                  const SizedBox(height: NawahSpacing.s2),
                  if (_loadingRoster)
                    const Padding(
                      padding: EdgeInsets.all(NawahSpacing.s4),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_roster.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(NawahSpacing.s4),
                      child: Text(
                        'لا يوجد طلاب مسجَّلون بهذا الفوج بعد',
                        style: TextStyle(color: NawahColors.textMuted),
                      ),
                    )
                  else
                    _RosterList(
                      roster: _roster,
                      statuses: _statuses,
                      onPick: _mark,
                    ),
                  const SizedBox(height: NawahSpacing.s5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStudentDialog extends StatefulWidget {
  const _AddStudentDialog({required this.repo, required this.cohortId});
  final AttendanceRepository repo;
  final String cohortId;

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  List<RosterEntry> _all = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.repo.fetchAddableStudents(widget.cohortId).then((v) {
      if (mounted) {
        setState(() {
          _all = v;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? _all
        : _all.where((s) => s.fullName.contains(_query.trim())).toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة طالب',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: NawahColors.ink,
                ),
              ),
              const SizedBox(height: NawahSpacing.s3),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'ابحث بالاسم',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: NawahSpacing.s3),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(NawahSpacing.s5),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(NawahSpacing.s5),
                        child: Text(
                          'لا يوجد طالب مطابق — إمّا مسجَّل أصلاً بهذا الفوج أو لا صلاحية لك برؤيته.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: NawahColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(filtered[i].fullName),
                          onTap: () => Navigator.of(context).pop(filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قائمة حضور بشكل صفوف متتالية (لا بطاقات مستقلّة)، وحالة كل طالب
/// تُختار من قائمة منسدلة — بنية تسمح لاحقاً بإضافة أعمدة تقييم إضافية
/// (الالتزام، حلّ المشكلات، التعاون...) بجانب كل صفّ بلا إعادة تصميم.
class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.roster,
    required this.statuses,
    required this.onPick,
  });

  final List<RosterEntry> roster;
  final Map<String, String> statuses;
  final void Function(String studentId, String status) onPick;

  static const _colors = <String, Color>{
    AttendanceStatus.present: NawahColors.green,
    AttendanceStatus.absent: NawahColors.rose,
    AttendanceStatus.late: NawahColors.accent,
    AttendanceStatus.excused: NawahColors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NawahColors.card,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        border: Border.all(color: NawahColors.border),
      ),
      child: Column(
        children: [
          for (final entry in roster) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NawahSpacing.s3,
                vertical: NawahSpacing.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: NawahColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s2),
                  _StatusDropdown(
                    status: statuses[entry.studentId],
                    color: _colors,
                    onChanged: (status) => onPick(entry.studentId, status),
                  ),
                ],
              ),
            ),
            if (entry != roster.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.status,
    required this.color,
    required this.onChanged,
  });

  final String? status;
  final Map<String, Color> color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = status;
    final tint = current == null ? NawahColors.textMuted : color[current]!;
    return DropdownButton<String>(
      value: current,
      hint: const Text('اختر', style: TextStyle(fontSize: 13)),
      underline: const SizedBox.shrink(),
      style: TextStyle(color: tint, fontWeight: FontWeight.w700, fontSize: 13),
      items: AttendanceStatus.all
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(AttendanceStatus.labels[s]!),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// عرض تفاصيل لقاء ماضٍ للقراءة فقط — اسم المدرّب والفوج/البرنامج، من
/// حضر ومن غاب، وملاحظات المدرّب. زر "تعديل" أعلى الشاشة يعيد فتح نموذج
/// اللقاء بنفس تاريخه.
class _MeetingDetailScreen extends StatelessWidget {
  const _MeetingDetailScreen({
    required this.cohort,
    required this.session,
    required this.roster,
    required this.statuses,
    required this.coTrainers,
    required this.onEdit,
  });

  final Cohort cohort;
  final ClassSession session;
  final List<RosterEntry> roster;
  final Map<String, String> statuses;
  final List<SessionCoTrainer> coTrainers;
  final VoidCallback onEdit;

  static const _colors = <String, Color>{
    AttendanceStatus.present: NawahColors.green,
    AttendanceStatus.absent: NawahColors.rose,
    AttendanceStatus.late: NawahColors.accent,
    AttendanceStatus.excused: NawahColors.cyan,
  };

  String _fmtTime(TimeOfDay? t) => t == null
      ? '—'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final d = session.sessionDate;
    return Scaffold(
      appBar: AppBar(
        title: Text('لقاء ${cohort.name} — ${d.year}/${d.month}/${d.day}'),
        actions: [
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(NawahSpacing.s4),
        children: [
          Container(
            padding: const EdgeInsets.all(NawahSpacing.s4),
            decoration: BoxDecoration(
              color: NawahColors.card,
              borderRadius: BorderRadius.circular(NawahRadius.md),
              border: Border.all(color: NawahColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.year}/${d.month}/${d.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: NawahColors.ink,
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                Text(
                  'الفوج: ${cohort.name}'
                  '${cohort.programTitle != null && cohort.programTitle!.isNotEmpty ? ' (${cohort.programTitle})' : ''}',
                  style: const TextStyle(color: NawahColors.textSoft),
                ),
                Text(
                  'المدرّب: ${cohort.trainerName ?? '—'}'
                  '${coTrainers.isNotEmpty ? ' + ${coTrainers.map((t) => t.fullName).join('، ')}' : ''}',
                  style: const TextStyle(color: NawahColors.textSoft),
                ),
                if (session.startsAt != null) ...[
                  const SizedBox(height: NawahSpacing.s1),
                  Text(
                    'الوقت: ${_fmtTime(session.startsAt)} – ${_fmtTime(session.endsAt)}',
                    style: const TextStyle(color: NawahColors.textSoft),
                  ),
                ],
                if (session.notes != null &&
                    session.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: NawahSpacing.s3),
                  const Text(
                    'ملاحظات المدرّب',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: NawahColors.textSoft,
                    ),
                  ),
                  const SizedBox(height: NawahSpacing.s1),
                  Text(
                    session.notes!,
                    style: const TextStyle(color: NawahColors.ink, height: 1.6),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: NawahSpacing.s4),
          const Text(
            'الحضور',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: NawahColors.ink,
            ),
          ),
          const SizedBox(height: NawahSpacing.s3),
          Container(
            decoration: BoxDecoration(
              color: NawahColors.card,
              borderRadius: BorderRadius.circular(NawahRadius.md),
              border: Border.all(color: NawahColors.border),
            ),
            child: Column(
              children: [
                for (final entry in roster) ...[
                  ListTile(
                    title: Text(entry.fullName),
                    trailing: Builder(
                      builder: (_) {
                        final status = statuses[entry.studentId];
                        if (status == null) {
                          return const Text(
                            '—',
                            style: TextStyle(color: NawahColors.textMuted),
                          );
                        }
                        final color = _colors[status]!;
                        return Text(
                          AttendanceStatus.labels[status]!,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                  if (entry != roster.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(NawahSpacing.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: NawahColors.textMuted),
          const SizedBox(height: NawahSpacing.s4),
          Text(
            title,
            style: const TextStyle(
              fontFamily: NawahFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: NawahColors.ink,
            ),
          ),
          const SizedBox(height: NawahSpacing.s2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NawahColors.textSoft, height: 1.7),
          ),
          if (action != null) ...[
            const SizedBox(height: NawahSpacing.s5),
            action!,
          ],
        ],
      ),
    ),
  );
}
