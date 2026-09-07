import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../cohorts/cohort.dart';
import '../cohorts/cohorts_repository.dart';
import 'attendance_repository.dart';
import 'attendance_status.dart';
import 'class_session.dart';

/// شاشة اللقاءات — يراها المدرّب والإدارة. RLS تُقيّد قائمة الأفواج
/// الظاهرة تلقائياً (المدرّب يرى فوجه فقط)، فلا حاجة لتمييز الدور هنا
/// إلا لإظهار فلتر اختيار المدرّب للإدارة وحدها (isAdmin).
///
/// "تسجيل لقاء" = وقته (من–إلى) + ملاحظات عمّا جرى فيه + حضور كل طالب.
/// اللقاء يُنشأ بصمت عند أول تفاعل حقيقي (حفظ تفاصيل أو تعليم حضور)، لا
/// عند مجرّد فتح الشاشة — فلا صفوف فارغة لمجرّد التصفّح.
///
/// نفس الشاشة تماماً للإدارة والمدرّب — الإضافة الوحيدة للإدارة فلتر
/// اختيار المدرّب فوق قائمة الأفواج (مصدر حقيقة واحد لمنطق التسجيل).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _cohortsRepo = const CohortsRepository();
  final _attendanceRepo = const AttendanceRepository();
  final _notes = TextEditingController();

  List<Cohort> _cohorts = [];
  String? _trainerFilter;
  Cohort? _selectedCohort;
  DateTime _date = DateTime.now();
  List<RosterEntry> _roster = [];
  Map<String, String> _statuses = {};
  String? _sessionId;
  TimeOfDay? _startsAt;
  TimeOfDay? _endsAt;
  bool _savingSession = false;
  bool _showHistory = false;
  List<ClassSession> _pastSessions = [];
  bool _loadingHistory = false;

  bool _loadingCohorts = true;
  bool _loadingRoster = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCohorts();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  List<Cohort> get _visibleCohorts => _trainerFilter == null
      ? _cohorts
      : _cohorts.where((c) => c.trainerId == _trainerFilter).toList();

  /// قائمة المدرّبين لفلتر الإدارة — مشتقّة من الأفواج المحمَّلة نفسها
  /// (كل فوج يحمل اسم مدرّبه مضمَّناً)، بلا استعلام إضافي.
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
      if (!mounted) return;
      setState(() {
        _cohorts = cohorts;
        _selectedCohort = _visibleCohorts.isEmpty
            ? null
            : _visibleCohorts.first;
        _loadingCohorts = false;
      });
      await _loadForSelection();
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
    _loadForSelection();
  }

  void _onCohortChanged(Cohort? c) {
    setState(() => _selectedCohort = c);
    _loadForSelection();
  }

  Future<void> _loadForSelection() =>
      _showHistory ? _loadHistory() : _loadRoster();

  Future<void> _toggleHistory(bool showHistory) async {
    setState(() => _showHistory = showHistory);
    await _loadForSelection();
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

  Future<void> _loadRoster() async {
    final cohort = _selectedCohort;
    if (cohort == null) return;
    setState(() => _loadingRoster = true);
    try {
      final roster = await _attendanceRepo.fetchRoster(cohort.id);
      final statuses = await _attendanceRepo.fetchStatuses(cohort.id, _date);
      final session = await _attendanceRepo.fetchSession(cohort.id, _date);
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _statuses = statuses;
        _sessionId = session?.id;
        _startsAt = session?.startsAt;
        _endsAt = session?.endsAt;
        _notes.text = session?.notes ?? '';
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
      await _loadRoster();
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

  /// يضمن وجود صفّ لقاء قبل أي كتابة فعلية (حفظ تفاصيل أو تعليم حضور) —
  /// لا يُنشأ صفّ لمجرّد فتح الشاشة أو التصفّح.
  Future<String?> _ensureSessionId() async {
    if (_sessionId != null) return _sessionId;
    final cohort = _selectedCohort;
    if (cohort == null) return null;
    final id = await _attendanceRepo.saveSession(
      cohortId: cohort.id,
      date: _date,
      startsAt: _startsAt,
      endsAt: _endsAt,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (mounted) setState(() => _sessionId = id);
    return id;
  }

  Future<void> _saveSessionDetails() async {
    final cohort = _selectedCohort;
    if (cohort == null) return;
    setState(() => _savingSession = true);
    try {
      final id = await _attendanceRepo.saveSession(
        cohortId: cohort.id,
        date: _date,
        startsAt: _startsAt,
        endsAt: _endsAt,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
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
    final cohort = _selectedCohort;
    if (cohort == null) return;
    final previous = _statuses[studentId];
    setState(
      () => _statuses = {..._statuses, studentId: status},
    ); // تحديث متفائل
    try {
      final sessionId = await _ensureSessionId();
      await _attendanceRepo.mark(
        cohortId: cohort.id,
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

  /// يفتح لقاءً ماضياً بتفاصيله من قائمة السجلّ. زر "تعديل" بالتفاصيل
  /// يعيد فتح نفس هذه الشاشة على وضع التسجيل بتاريخ ذاك اللقاء.
  Future<void> _openPastSession(ClassSession session) async {
    final cohort = _selectedCohort;
    if (cohort == null) return;
    try {
      final roster = await _attendanceRepo.fetchRoster(cohort.id);
      final statuses = await _attendanceRepo.fetchStatuses(
        cohort.id,
        session.sessionDate,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _MeetingDetailScreen(
            cohortName: cohort.name,
            session: session,
            roster: roster,
            statuses: statuses,
            onEdit: () {
              Navigator.of(context).pop();
              setState(() {
                _showHistory = false;
                _date = session.sessionDate;
              });
              _loadRoster();
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

  String _fmtTime(TimeOfDay? t) => t == null ? '—' : t.format(context);

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

    return RefreshIndicator(
      onRefresh: _loadForSelection,
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
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: _onTrainerFilterChanged,
              ),
              const SizedBox(height: NawahSpacing.s3),
            ],
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Cohort>(
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
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onCohortChanged,
                  ),
                ),
                if (!_showHistory) ...[
                  const SizedBox(width: NawahSpacing.s3),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('${_date.year}/${_date.month}/${_date.day}'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: NawahSpacing.s4),

            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('تسجيل لقاء'),
                  icon: Icon(Icons.edit_calendar_outlined, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('اللقاءات السابقة'),
                  icon: Icon(Icons.history, size: 18),
                ),
              ],
              selected: {_showHistory},
              onSelectionChanged: (s) => _toggleHistory(s.first),
            ),
            const SizedBox(height: NawahSpacing.s4),

            if (_selectedCohort == null)
              const _Empty(
                icon: Icons.groups_2_outlined,
                title: 'اختر فوجاً',
                subtitle: 'اختر فوجاً من القائمة أعلاه لعرض لقاءاته.',
              )
            else if (_showHistory)
              _buildHistory()
            else
              _buildLogging(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Padding(
        padding: EdgeInsets.all(NawahSpacing.s6),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_pastSessions.isEmpty) {
      return const _Empty(
        icon: Icons.event_busy_outlined,
        title: 'لا يوجد لقاءات مسجَّلة بعد بهذا الفوج',
        subtitle: 'سجّل أول لقاء من تبويب "تسجيل لقاء".',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: NawahColors.card,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        border: Border.all(color: NawahColors.border),
      ),
      child: Column(
        children: [
          for (final s in _pastSessions) ...[
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
                    : '${_fmtTime(s.startsAt)} – ${_fmtTime(s.endsAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(
                Icons.chevron_left,
                color: NawahColors.textMuted,
              ),
            ),
            if (s != _pastSessions.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildLogging() {
    final duration = ClassSession(
      id: '',
      cohortId: '',
      sessionDate: _date,
      startsAt: _startsAt,
      endsAt: _endsAt,
    ).hours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Text(
                'تفاصيل اللقاء',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: NawahColors.ink,
                ),
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
              const SizedBox(height: NawahSpacing.s3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: _savingSession ? null : _saveSessionDetails,
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
            ],
          ),
        ),
        const SizedBox(height: NawahSpacing.s4),

        if (_loadingRoster)
          const Padding(
            padding: EdgeInsets.all(NawahSpacing.s6),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_roster.isEmpty)
          const _Empty(
            icon: Icons.person_off_outlined,
            title: 'لا يوجد طلاب مسجَّلون بهذا الفوج',
            subtitle: 'سجّل طلاباً بهذا الفوج من شاشة الأفواج أولاً.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الحضور',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: NawahColors.ink,
                ),
              ),
              const SizedBox(height: NawahSpacing.s3),
              _RosterList(roster: _roster, statuses: _statuses, onPick: _mark),
            ],
          ),
      ],
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

/// عرض تفاصيل لقاء ماضٍ للقراءة فقط — من حضر، من غاب، وملاحظات المدرّب.
/// زر "تعديل" أعلى الشاشة يعيد فتح وضع التسجيل بنفس تاريخ هذا اللقاء.
class _MeetingDetailScreen extends StatelessWidget {
  const _MeetingDetailScreen({
    required this.cohortName,
    required this.session,
    required this.roster,
    required this.statuses,
    required this.onEdit,
  });

  final String cohortName;
  final ClassSession session;
  final List<RosterEntry> roster;
  final Map<String, String> statuses;
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
        title: Text('لقاء $cohortName — ${d.year}/${d.month}/${d.day}'),
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
                if (session.startsAt != null) ...[
                  const SizedBox(height: NawahSpacing.s2),
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
