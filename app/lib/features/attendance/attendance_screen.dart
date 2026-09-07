import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../cohorts/cohort.dart';
import '../cohorts/cohorts_repository.dart';
import 'attendance_repository.dart';
import 'attendance_status.dart';
import 'class_session.dart';

/// شاشة تسجيل الحصة — يراها المدرّب والإدارة. RLS تُقيّد قائمة الأفواج
/// الظاهرة تلقائياً (المدرّب يرى فوجه فقط)، فلا حاجة لتمييز الدور هنا.
///
/// "تسجيل حصة" = وقتها (من–إلى) + ملاحظات عمّا جرى فيها + حضور كل طالب.
/// الحصة تُنشأ بصمت عند أول تفاعل حقيقي (حفظ تفاصيل أو تعليم حضور)، لا
/// عند مجرّد فتح الشاشة — فلا صفوف فارغة لمجرّد التصفّح.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _cohortsRepo = const CohortsRepository();
  final _attendanceRepo = const AttendanceRepository();
  final _notes = TextEditingController();

  List<Cohort> _cohorts = [];
  Cohort? _selectedCohort;
  DateTime _date = DateTime.now();
  List<RosterEntry> _roster = [];
  Map<String, String> _statuses = {};
  String? _sessionId;
  TimeOfDay? _startsAt;
  TimeOfDay? _endsAt;
  bool _savingSession = false;

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
        _selectedCohort = cohorts.isEmpty ? null : cohorts.first;
        _loadingCohorts = false;
      });
      if (_selectedCohort != null) await _loadRoster();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCohorts = false;
        _error = 'تعذّر تحميل الأفواج. تحقّق من اتصالك ثم أعد المحاولة.';
      });
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
      helpText: 'تاريخ الحصة',
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
      helpText: isStart ? 'وقت بداية الحصة' : 'وقت نهاية الحصة',
    );
    if (picked != null) {
      setState(() => isStart ? _startsAt = picked : _endsAt = picked);
    }
  }

  /// يضمن وجود صفّ حصة قبل أي كتابة فعلية (حفظ تفاصيل أو تعليم حضور) —
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
          .showSnackBar(const SnackBar(content: Text('تم حفظ تفاصيل الحصة')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر حفظ تفاصيل الحصة — حاول مجدداً.'),
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

    final duration = ClassSession(
      id: '',
      cohortId: '',
      sessionDate: _date,
      startsAt: _startsAt,
      endsAt: _endsAt,
    ).hours;

    return RefreshIndicator(
      onRefresh: _loadRoster,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(NawahSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Cohort>(
                    value: _selectedCohort,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _cohorts
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
                    onChanged: (c) {
                      setState(() => _selectedCohort = c);
                      _loadRoster();
                    },
                  ),
                ),
                const SizedBox(width: NawahSpacing.s3),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text('${_date.year}/${_date.month}/${_date.day}'),
                ),
              ],
            ),
            const SizedBox(height: NawahSpacing.s4),

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
                    'تفاصيل الحصة',
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
                      labelText: 'ماذا جرى بهذه الحصة؟ (اختياري)',
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
                      label: const Text('حفظ تفاصيل الحصة'),
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
                  ..._roster.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: NawahSpacing.s2),
                      child: _AttendanceRow(
                        name: entry.fullName,
                        status: _statuses[entry.studentId],
                        onPick: (status) => _mark(entry.studentId, status),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.name,
    required this.status,
    required this.onPick,
  });
  final String name;
  final String? status;
  final ValueChanged<String> onPick;

  static const _colors = <String, Color>{
    AttendanceStatus.present: NawahColors.green,
    AttendanceStatus.absent: NawahColors.rose,
    AttendanceStatus.late: NawahColors.accent,
    AttendanceStatus.excused: NawahColors.cyan,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NawahSpacing.s3),
      decoration: BoxDecoration(
        color: NawahColors.card,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        border: Border.all(color: NawahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: NawahColors.ink,
            ),
          ),
          const SizedBox(height: NawahSpacing.s2),
          Wrap(
            spacing: NawahSpacing.s2,
            children: AttendanceStatus.all.map((s) {
              final selected = status == s;
              final color = _colors[s]!;
              return ChoiceChip(
                label: Text(AttendanceStatus.labels[s]!),
                selected: selected,
                onSelected: (_) => onPick(s),
                selectedColor: color.withValues(alpha: .18),
                side: selected ? BorderSide(color: color) : null,
                labelStyle: TextStyle(
                  color: selected ? color : NawahColors.textSoft,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
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
