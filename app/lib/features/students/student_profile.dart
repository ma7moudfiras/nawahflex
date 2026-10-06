import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../brand/level_frame.dart';
import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/open_url.dart';
import '../../core/supabase.dart';
import '../../shared/section_card.dart';
import '../../shared/sheets.dart';
import '../attendance/attendance_repository.dart';
import '../attendance/attendance_status.dart';
import '../auth/profile.dart';
import '../programs/programs_repository.dart';
import '../progress/progress_models.dart';
import '../progress/progress_repository.dart';
import '../progress/progress_sheets.dart';
import 'student.dart';
import 'student_form.dart';
import 'students_repository.dart';

typedef _Level = ({int level, String title, int minPoints});

/// كل ما يعرضه الملف، يُجلب معاً ويظهر دفعة واحدة — لا بطاقات تقفز
/// واحدة بعد أخرى (درس بوابة طبيعة فلسطين: traineeOverviewProvider).
class _ProfileData {
  const _ProfileData({
    required this.student,
    required this.progress,
    required this.levels,
    required this.attendance,
    required this.catalog,
    required this.earned,
    required this.skills,
    required this.skillLevels,
    required this.notes,
  });

  final Student student;
  final StudentProgress progress;
  final List<_Level> levels;
  final Map<String, int> attendance;
  final List<BadgeDef> catalog;
  final List<EarnedBadge> earned;
  final List<Skill> skills;
  final Map<String, int> skillLevels;
  final List<StudentNote> notes;

  String? levelTitle(int level) => levels.where((l) => l.level == level).firstOrNull?.title;
}

/// ملف الطالب: إطار المستوى، والإحصاءات، والشارات، والمهارات، والملاحظات،
/// والحضور، والبيانات. يُعرض صفحةً (`/students/:id`) أو لوحةً في عرض
/// القائمة العريض ([embedded]).
///
/// [viewer] يحدّد الأزرار الظاهرة فقط؛ الصلاحية الحقيقية في RLS (0012).
class StudentProfileView extends StatefulWidget {
  const StudentProfileView({
    super.key,
    required this.studentId,
    required this.viewer,
    this.embedded = false,
    this.onChanged,
  });

  final String studentId;
  final Profile viewer;
  final bool embedded;

  /// يُستدعى بعد تعديل بيانات الطالب — لتحديث القائمة خلفه.
  final VoidCallback? onChanged;

  @override
  State<StudentProfileView> createState() => _StudentProfileViewState();
}

class _StudentProfileViewState extends State<StudentProfileView> {
  static const _students = StudentsRepository();
  static const _progress = ProgressRepository();
  static const _attendance = AttendanceRepository();

  _ProfileData? _data;
  String? _error;
  bool _missing = false;

  bool get _canTeach => widget.viewer.canManage || widget.viewer.isTrainer;
  bool get _canManage => widget.viewer.canManage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudentProfileView old) {
    super.didUpdateWidget(old);
    if (old.studentId != widget.studentId) {
      setState(() => _data = null);
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.studentId;
    setState(() {
      _error = null;
      _missing = false;
    });
    try {
      final student = await _students.fetchOne(id);
      if (student == null) {
        if (mounted && widget.studentId == id) setState(() => _missing = true);
        return;
      }
      final r = await Future.wait<Object>([
        _progress.fetchOne(id),
        _progress.fetchLevels(),
        _attendance.fetchStudentAttendanceCounts(id),
        _progress.fetchBadgeCatalog(),
        _progress.fetchEarnedBadges(id),
        _progress.fetchSkills(student.programIds),
        _progress.fetchSkillLevels(id),
        _progress.fetchNotes(id),
      ]);
      if (!mounted || widget.studentId != id) return;
      setState(() => _data = _ProfileData(
            student: student,
            progress: r[0] as StudentProgress,
            levels: r[1] as List<_Level>,
            attendance: r[2] as Map<String, int>,
            catalog: r[3] as List<BadgeDef>,
            earned: r[4] as List<EarnedBadge>,
            skills: r[5] as List<Skill>,
            skillLevels: r[6] as Map<String, int>,
            notes: r[7] as List<StudentNote>,
          ));
    } catch (e, st) {
      if (mounted && widget.studentId == id) setState(() => _error = userMessageFor(e, st));
    }
  }

  // ---------- الإجراءات ----------

  Future<void> _awardBadge(_ProfileData d) async {
    final earnedIds = d.earned.map((e) => e.badgeId).toSet();
    final available = d.catalog
        .where((b) => b.isActive && !earnedIds.contains(b.id))
        .where((b) => b.programId == null || d.student.programIds.contains(b.programId))
        .toList();
    if (await showAwardBadgeSheet(context, studentId: d.student.id, studentName: d.student.fullName, available: available)) {
      _load();
    }
  }

  Future<void> _openEarned(_ProfileData d, EarnedBadge e, BadgeDef b) async {
    final mine = e.awardedBy == Db.user?.id;
    if (await showEarnedBadgeSheet(context, badge: b, earned: e, canRevoke: _canManage || (mine && _canTeach))) {
      _load();
    }
  }

  Future<void> _setSkill(_ProfileData d, Skill s) async {
    final level = await showSkillLevelSheet(context, studentId: d.student.id, skill: s, current: d.skillLevels[s.id]);
    if (level != null) _load();
  }

  Future<void> _addNote(_ProfileData d) async {
    if (await showAddNoteSheet(context, studentId: d.student.id)) _load();
  }

  Future<void> _deleteNote(StudentNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملاحظة؟'),
        content: const Text('لا يمكن التراجع عن الحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _progress.deleteNote(n.id);
      _load();
    } catch (e, st) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessageFor(e, st))));
    }
  }

  Future<void> _edit(_ProfileData d) async {
    try {
      final programs = await const ProgramsRepository().fetch();
      if (!mounted) return;
      await showAdaptiveSheet<void>(
        context,
        builder: (_) => StudentForm(
          initial: d.student,
          allPrograms: programs,
          initialProgramIds: d.student.programIds,
          onSubmit: (s, programIds) async {
            await _students.update(d.student.id, s);
            await _students.setPrograms(d.student.id, programIds);
          },
        ),
      );
      widget.onChanged?.call();
      _load();
    } catch (e, st) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessageFor(e, st))));
    }
  }

  Future<void> _open(String url) async {
    if (!await openExternal(url) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط.')));
    }
  }

  // ---------- البناء ----------

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_missing) {
      body = const _Message(icon: Icons.person_off_outlined, text: 'هذا الطالب غير موجود، أو لا تملك صلاحية عرضه.');
    } else if (_error != null && _data == null) {
      body = _Message(icon: Icons.wifi_off, text: _error!, onRetry: _load);
    } else if (_data == null) {
      body = const _Skeleton();
    } else {
      body = _content(_data!);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, box) {
          final pad = box.maxWidth < 600 ? NawahSpacing.s4 : NawahSpacing.s6;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, widget.embedded ? pad : NawahSpacing.s2, pad, NawahSpacing.s7),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.embedded) const _BackRow(),
                    body,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(_ProfileData d) {
    final hero = _Hero(
      data: d,
      onEdit: _canManage ? () => _edit(d) : null,
      onLegend: () => showLevelsLegend(context, levels: d.levels, current: d.progress.level),
    );
    final stats = _Stats(progress: d.progress);
    final badges = _badgesCard(d);
    final skills = _skillsCard(d);
    final notes = _notesCard(d);
    final attendance = SectionCard(
      title: 'الحضور',
      icon: Icons.event_available_outlined,
      child: _AttendanceSummary(counts: d.attendance),
    );
    final details = _DetailsCard(student: d.student, onOpen: _open, showInternal: _canTeach);

    return LayoutBuilder(
      builder: (context, box) {
        const gap = SizedBox(height: NawahSpacing.s4);
        if (box.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [hero, gap, stats, gap, badges, gap, skills, gap, notes, gap, attendance, gap, details],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            gap,
            stats,
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: Column(children: [badges, gap, skills, gap, notes])),
                const SizedBox(width: NawahSpacing.s4),
                Expanded(flex: 2, child: Column(children: [attendance, gap, details])),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _badgesCard(_ProfileData d) {
    final byId = {for (final b in d.catalog) b.id: b};
    final earned = d.earned.where((e) => byId.containsKey(e.badgeId)).toList();
    return SectionCard(
      title: 'الشارات',
      icon: Icons.military_tech_outlined,
      action: _canTeach
          ? TextButton.icon(
              onPressed: () => _awardBadge(d),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('منح شارة'),
            )
          : null,
      child: earned.isEmpty
          ? const _Hint('لم ينل شارات بعد. كل شارة تضيف نقاطاً وتقرّبه من المستوى التالي.')
          : Wrap(
              spacing: NawahSpacing.s2,
              runSpacing: NawahSpacing.s2,
              children: [
                for (final e in earned)
                  _BadgeChip(badge: byId[e.badgeId]!, onTap: () => _openEarned(d, e, byId[e.badgeId]!)),
              ],
            ),
    );
  }

  Widget _skillsCard(_ProfileData d) {
    final Widget child;
    if (d.student.programIds.isEmpty) {
      child = const _Hint('سجّل الطالب في برنامج ليظهر تقدّمه في مهاراته.');
    } else if (d.skills.isEmpty) {
      child = _Hint(_canManage
          ? 'لم تُضف مهارات لبرامجه بعد — أضفها من قسم «البرامج».'
          : 'لم تُحدَّد مهارات برامجه بعد.');
    } else {
      final multi = d.student.programIds.length > 1;
      final children = <Widget>[];
      for (var i = 0; i < d.student.programIds.length; i++) {
        final pid = d.student.programIds[i];
        final list = d.skills.where((s) => s.programId == pid).toList();
        if (list.isEmpty) continue;
        if (multi) {
          children.add(Padding(
            padding: const EdgeInsets.only(top: NawahSpacing.s2, bottom: NawahSpacing.s1),
            child: Text(d.student.programTitles[i],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NawahColors.textMuted)),
          ));
        }
        for (final s in list) {
          final lv = d.skillLevels[s.id];
          children.add(InkWell(
            onTap: _canTeach ? () => _setSkill(d, s) : null,
            borderRadius: BorderRadius.circular(NawahRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: NawahSpacing.s2, horizontal: NawahSpacing.s1),
              child: Row(
                children: [
                  Expanded(child: Text(s.title, style: const TextStyle(color: NawahColors.text))),
                  const SizedBox(width: NawahSpacing.s2),
                  SkillMeter(level: lv ?? 0, width: 64),
                  const SizedBox(width: NawahSpacing.s2),
                  SizedBox(
                    width: 52,
                    child: Text(
                      lv == null ? 'لم يُقيَّم' : SkillLevel.label(lv),
                      style: TextStyle(fontSize: 12, color: lv == null ? NawahColors.textMuted : NawahColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ));
        }
      }
      child = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return SectionCard(title: 'المهارات', icon: Icons.insights_outlined, child: child);
  }

  Widget _notesCard(_ProfileData d) {
    final me = Db.user?.id;
    final fmt = DateFormat('d MMMM y', 'ar');
    return SectionCard(
      title: 'ملاحظات المدرّب',
      icon: Icons.sticky_note_2_outlined,
      action: _canTeach
          ? TextButton.icon(onPressed: () => _addNote(d), icon: const Icon(Icons.add, size: 18), label: const Text('ملاحظة'))
          : null,
      child: d.notes.isEmpty
          ? const _Hint('لا ملاحظات بعد. الملاحظات المعلَّمة «يراها ولي الأمر» تظهر في بوابة الأهل.')
          : Column(
              children: [
                for (final n in d.notes)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: NawahSpacing.s2),
                    padding: const EdgeInsets.all(NawahSpacing.s3),
                    decoration: BoxDecoration(
                      color: NawahColors.paper,
                      borderRadius: BorderRadius.circular(NawahRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(fmt.format(n.createdAt), style: const TextStyle(fontSize: 12, color: NawahColors.textMuted)),
                            if (!n.visibleToGuardian) ...[
                              const SizedBox(width: NawahSpacing.s2),
                              const Icon(Icons.lock_outline, size: 14, color: NawahColors.textMuted),
                              const Text(' للفريق فقط', style: TextStyle(fontSize: 12, color: NawahColors.textMuted)),
                            ],
                            const Spacer(),
                            if (_canManage || (n.authorId == me && _canTeach))
                              IconButton(
                                tooltip: 'حذف',
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                onPressed: () => _deleteNote(n),
                                icon: const Icon(Icons.delete_outline, color: NawahColors.textMuted),
                              ),
                          ],
                        ),
                        Text(n.body, style: const TextStyle(height: 1.8, color: NawahColors.text)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => context.canPop() ? context.pop() : context.go('/students'),
        // Icons.arrow_back يتبع اتجاه النص: يشير يميناً في العربية.
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('رجوع'),
      ),
    );
  }
}

/// رأس الملف على الكحلي: الإطار، والاسم، والمستوى، والطريق إلى التالي.
class _Hero extends StatelessWidget {
  const _Hero({required this.data, required this.onLegend, this.onEdit});
  final _ProfileData data;
  final VoidCallback onLegend;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final s = data.student;
    final p = data.progress;
    final nextTitle = data.levelTitle(p.level + 1);
    final sub = [
      if (s.age != null) '${s.age} سنة',
      ...s.programTitles,
      if (!s.isActive) 'غير نشط',
    ].join(' · ');

    final frame = InkWell(
      onTap: onLegend,
      borderRadius: BorderRadius.circular(NawahRadius.md),
      child: Tooltip(
        message: 'ما معنى الإطار؟',
        child: LevelFrame(
          level: p.level,
          size: 92,
          color: NawahColors.textInvert,
          background: NawahColors.ink,
          child: InitialAvatar(initial: s.initial, background: NawahColors.inkSoft, foreground: NawahColors.textInvert),
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.fullName,
          style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 22, color: NawahColors.textInvert),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: NawahColors.invertSoft, fontSize: 13)),
        ],
        const SizedBox(height: NawahSpacing.s3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: NawahColors.accent, borderRadius: BorderRadius.circular(NawahRadius.full)),
              child: Text(
                'المستوى ${p.level} · ${p.levelTitle}',
                style: const TextStyle(color: NawahColors.onAccent, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(width: NawahSpacing.s2),
            Text('${p.points} نقطة', style: const TextStyle(color: NawahColors.textInvert, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: NawahSpacing.s3),
        ClipRRect(
          borderRadius: BorderRadius.circular(NawahRadius.full),
          child: LinearProgressIndicator(
            value: p.levelFraction,
            minHeight: 8,
            color: NawahColors.accent,
            backgroundColor: NawahColors.inkLine,
          ),
        ),
        const SizedBox(height: NawahSpacing.s1),
        Text(
          p.isMaxLevel
              ? 'اكتمل وجه الروبوت — أعلى مستوى.'
              : '${p.pointsToNext} نقطة إلى «${nextTitle ?? 'المستوى التالي'}»',
          style: const TextStyle(color: NawahColors.invertSoft, fontSize: 12),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(NawahSpacing.s5),
      decoration: BoxDecoration(color: NawahColors.ink, borderRadius: BorderRadius.circular(NawahRadius.lg)),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) => box.maxWidth < 420
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [frame, const SizedBox(height: NawahSpacing.s3), info])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [frame, const SizedBox(width: NawahSpacing.s5), Expanded(child: info)],
                  ),
          ),
          if (onEdit != null)
            PositionedDirectional(
              top: -8,
              end: -8,
              child: IconButton(
                tooltip: 'تعديل البيانات',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: NawahColors.invertSoft),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.progress});
  final StudentProgress progress;

  @override
  Widget build(BuildContext context) {
    final rate = progress.attendanceRate;
    final tiles = [
      StatTile(label: 'النقاط', value: '${progress.points}', icon: Icons.bolt_outlined),
      StatTile(label: 'الحضور', value: rate == null ? '—' : '$rate%', icon: Icons.event_available_outlined),
      StatTile(label: 'الشارات', value: '${progress.badgesCount}', icon: Icons.military_tech_outlined),
      StatTile(label: 'المشاريع', value: '${progress.projectsCount}', icon: Icons.precision_manufacturing_outlined),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth < 520 ? 2 : 4;
        final w = (box.maxWidth - NawahSpacing.s3 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: NawahSpacing.s3,
          runSpacing: NawahSpacing.s3,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.onTap});
  final BadgeDef badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NawahRadius.full),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: NawahColors.paper,
            borderRadius: BorderRadius.circular(NawahRadius.full),
            border: Border.all(color: NawahColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeDisc(icon: badge.icon, size: 28),
              const SizedBox(width: NawahSpacing.s2),
              Text(badge.title, style: const TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.student, required this.onOpen, required this.showInternal});
  final Student student;
  final ValueChanged<String> onOpen;
  final bool showInternal;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final gender = s.gender == 'm' ? 'ذكر' : s.gender == 'f' ? 'أنثى' : null;
    final hasPhone = s.guardianPhone != null && s.guardianPhone!.isNotEmpty;
    final hasEmail = s.guardianEmail != null && s.guardianEmail!.isNotEmpty;
    return SectionCard(
      title: 'البيانات',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.birthDate != null) _Field('تاريخ الميلاد', DateFormat('d MMMM y', 'ar').format(s.birthDate!)),
          if (gender != null) _Field('الجنس', gender),
          _Field('مسجَّل منذ', DateFormat('MMMM y', 'ar').format(s.createdAt)),
          if (s.guardianName != null && s.guardianName!.isNotEmpty) _Field('ولي الأمر', s.guardianName!),
          if (hasPhone || hasEmail) ...[
            const SizedBox(height: NawahSpacing.s2),
            Wrap(
              spacing: NawahSpacing.s2,
              runSpacing: NawahSpacing.s2,
              children: [
                if (hasPhone) ...[
                  FilledButton.icon(
                    onPressed: () => onOpen(s.whatsappUrl),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('واتساب'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onOpen('tel:${s.guardianPhone}'),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(s.guardianPhone!, textDirection: TextDirection.ltr),
                  ),
                ],
                if (hasEmail)
                  OutlinedButton.icon(
                    onPressed: () => onOpen('mailto:${s.guardianEmail}'),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(s.guardianEmail!, textDirection: TextDirection.ltr),
                  ),
              ],
            ),
          ],
          if (showInternal && s.notes != null && s.notes!.isNotEmpty) ...[
            const SizedBox(height: NawahSpacing.s4),
            const Text('ملاحظات داخلية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NawahColors.textMuted)),
            const SizedBox(height: NawahSpacing.s1),
            Text(s.notes!, style: const TextStyle(height: 1.8)),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: NawahSpacing.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 104, child: Text(label, style: const TextStyle(color: NawahColors.textMuted, fontSize: 13))),
            Expanded(child: Text(value, style: const TextStyle(color: NawahColors.text))),
          ],
        ),
      );
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final c = counts;
    final total = c.values.fold(0, (a, b) => a + b);
    if (total == 0) return const _Hint('لا يوجد سجلّ حضور بعد.');
    final present = (c[AttendanceStatus.present] ?? 0) + (c[AttendanceStatus.late] ?? 0);
    final rate = (present / total * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$rate% نسبة الحضور ($present من $total حصة)',
          style: const TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink),
        ),
        const SizedBox(height: NawahSpacing.s2),
        Wrap(
          spacing: NawahSpacing.s2,
          runSpacing: NawahSpacing.s2,
          children: [
            for (final s in AttendanceStatus.all.where((s) => (c[s] ?? 0) > 0))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: NawahColors.paper, borderRadius: BorderRadius.circular(NawahRadius.full)),
                child: Text('${AttendanceStatus.labels[s]}: ${c[s]}', style: const TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.7));
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: NawahSpacing.s7),
        child: Column(
          children: [
            Icon(icon, size: 44, color: NawahColors.textMuted),
            const SizedBox(height: NawahSpacing.s3),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: NawahColors.textSoft, height: 1.8)),
            if (onRetry != null) ...[
              const SizedBox(height: NawahSpacing.s4),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('إعادة المحاولة')),
            ],
          ],
        ),
      );
}

/// هيكل الصفحة قبل وصول البيانات — نفس أبعاد المحتوى فلا تقفز عند ظهوره.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonBox(height: 150, radius: NawahRadius.lg),
        const SizedBox(height: NawahSpacing.s4),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: NawahSpacing.s3),
              const Expanded(child: SkeletonBox(height: 72, radius: NawahRadius.md)),
            ],
          ],
        ),
        const SizedBox(height: NawahSpacing.s4),
        const SkeletonBox(height: 120, radius: NawahRadius.md),
        const SizedBox(height: NawahSpacing.s4),
        const SkeletonBox(height: 160, radius: NawahRadius.md),
      ],
    );
  }
}
