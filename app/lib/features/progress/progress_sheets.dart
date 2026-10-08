import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../brand/level_frame.dart';
import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../shared/form_error.dart';
import '../../shared/sheets.dart';
import 'badge_icons.dart';
import 'progress_models.dart';
import 'progress_repository.dart';

const _repo = ProgressRepository();

/// رأس موحّد للألواح: عنوان وسطر شرح.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(NawahSpacing.s5, NawahSpacing.s4, NawahSpacing.s5, NawahSpacing.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: NawahFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: NawahColors.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: NawahSpacing.s1),
              Text(subtitle!, style: const TextStyle(color: NawahColors.textMuted, fontSize: 13)),
            ],
          ],
        ),
      );
}

/// قرص الأيقونة — نفس رسم الشارة في كل مكان.
class BadgeDisc extends StatelessWidget {
  const BadgeDisc({super.key, required this.icon, this.size = 32, this.muted = false});
  final String icon;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: muted ? NawahColors.paperDeep : NawahColors.ink,
          shape: BoxShape.circle,
        ),
        child: Icon(
          badgeIcon(icon),
          size: size * 0.56,
          color: muted ? NawahColors.textMuted : NawahColors.textInvert,
        ),
      );
}

// ---------------------------------------------------------------------------
// منح شارة
// ---------------------------------------------------------------------------

/// يرجع true إن مُنحت شارة.
Future<bool> showAwardBadgeSheet(
  BuildContext context, {
  required String studentId,
  required String studentName,
  required List<BadgeDef> available,
}) async {
  final done = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _AwardBadgeSheet(studentId: studentId, studentName: studentName, available: available),
  );
  return done ?? false;
}

class _AwardBadgeSheet extends StatefulWidget {
  const _AwardBadgeSheet({required this.studentId, required this.studentName, required this.available});
  final String studentId;
  final String studentName;
  final List<BadgeDef> available;

  @override
  State<_AwardBadgeSheet> createState() => _AwardBadgeSheetState();
}

class _AwardBadgeSheetState extends State<_AwardBadgeSheet> {
  String? _busyId;
  String? _error;

  Future<void> _award(BadgeDef b) async {
    setState(() {
      _busyId = b.id;
      _error = null;
    });
    try {
      await _repo.awardBadge(widget.studentId, b.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busyId = null;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(title: 'منح شارة', subtitle: 'اختر شارة نالها ${widget.studentName}.'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NawahSpacing.s5),
            child: FormErrorBanner(message: _error),
          ),
          if (widget.available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(NawahSpacing.s5),
              child: Text('نال الطالب كل الشارات المتاحة.', style: TextStyle(color: NawahColors.textSoft)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(NawahSpacing.s3, 0, NawahSpacing.s3, NawahSpacing.s4),
                itemCount: widget.available.length,
                separatorBuilder: (_, _) => const SizedBox(height: NawahSpacing.s1),
                itemBuilder: (_, i) {
                  final b = widget.available[i];
                  final busy = _busyId == b.id;
                  return ListTile(
                    enabled: _busyId == null,
                    onTap: () => _award(b),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NawahRadius.sm)),
                    leading: BadgeDisc(icon: b.icon, size: 40),
                    title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(b.description),
                    trailing: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('+${b.points}', style: const TextStyle(color: NawahColors.accentInk, fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// تفاصيل شارة نالها الطالب (وسحبها)
// ---------------------------------------------------------------------------

/// يرجع true إن سُحبت الشارة.
Future<bool> showEarnedBadgeSheet(
  BuildContext context, {
  required BadgeDef badge,
  required EarnedBadge earned,
  required bool canRevoke,
}) async {
  final revoked = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _EarnedBadgeSheet(badge: badge, earned: earned, canRevoke: canRevoke),
  );
  return revoked ?? false;
}

class _EarnedBadgeSheet extends StatefulWidget {
  const _EarnedBadgeSheet({required this.badge, required this.earned, required this.canRevoke});
  final BadgeDef badge;
  final EarnedBadge earned;
  final bool canRevoke;

  @override
  State<_EarnedBadgeSheet> createState() => _EarnedBadgeSheetState();
}

class _EarnedBadgeSheetState extends State<_EarnedBadgeSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _revoke() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.revokeBadge(widget.earned.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(NawahSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: BadgeDisc(icon: b.icon, size: 64)),
            const SizedBox(height: NawahSpacing.s3),
            Text(
              b.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 20, color: NawahColors.ink),
            ),
            const SizedBox(height: NawahSpacing.s2),
            Text(b.description, textAlign: TextAlign.center, style: const TextStyle(color: NawahColors.textSoft, height: 1.7)),
            const SizedBox(height: NawahSpacing.s2),
            Text(
              textAlign: TextAlign.center,
              'نالها في ${DateFormat('d MMMM y', 'ar').format(widget.earned.awardedAt)} · +${b.points} نقطة',
              style: const TextStyle(color: NawahColors.textMuted, fontSize: 12),
            ),
            if (widget.earned.note != null) ...[
              const SizedBox(height: NawahSpacing.s3),
              Text(widget.earned.note!, textAlign: TextAlign.center),
            ],
            if (widget.canRevoke) ...[
              const SizedBox(height: NawahSpacing.s5),
              FormErrorBanner(message: _error),
              TextButton.icon(
                onPressed: _busy ? null : _revoke,
                style: TextButton.styleFrom(foregroundColor: NawahColors.err),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('سحب الشارة (مُنحت خطأً)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// درجة مهارة
// ---------------------------------------------------------------------------

/// يرجع الدرجة الجديدة إن حُفظت.
Future<int?> showSkillLevelSheet(
  BuildContext context, {
  required String studentId,
  required Skill skill,
  required int? current,
}) {
  return showAdaptiveSheet<int>(
    context,
    builder: (_) => _SkillLevelSheet(studentId: studentId, skill: skill, current: current),
  );
}

class _SkillLevelSheet extends StatefulWidget {
  const _SkillLevelSheet({required this.studentId, required this.skill, required this.current});
  final String studentId;
  final Skill skill;
  final int? current;

  @override
  State<_SkillLevelSheet> createState() => _SkillLevelSheetState();
}

class _SkillLevelSheetState extends State<_SkillLevelSheet> {
  int? _busyLevel;
  String? _error;

  Future<void> _set(int level) async {
    if (level == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busyLevel = level;
      _error = null;
    });
    try {
      await _repo.setSkillLevel(widget.studentId, widget.skill.id, level);
      if (mounted) Navigator.of(context).pop(level);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busyLevel = null;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(title: widget.skill.title, subtitle: widget.skill.description ?? 'أين وصل الطالب في هذه المهارة؟'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NawahSpacing.s5),
            child: FormErrorBanner(message: _error),
          ),
          for (var lv = 1; lv <= SkillLevel.max; lv++)
            ListTile(
              enabled: _busyLevel == null,
              onTap: () => _set(lv),
              contentPadding: const EdgeInsets.symmetric(horizontal: NawahSpacing.s5),
              leading: SkillMeter(level: lv, width: 64),
              title: Text(SkillLevel.label(lv), style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: _busyLevel == lv
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : lv == widget.current
                      ? const Icon(Icons.check_circle, color: NawahColors.ok)
                      : null,
            ),
          const SizedBox(height: NawahSpacing.s4),
        ],
      ),
    );
  }
}

/// أربع شرائح؛ المكتمل منها بالكحلي — درجة المهارة بلمحة.
class SkillMeter extends StatelessWidget {
  const SkillMeter({super.key, required this.level, this.width = 72});
  final int level;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SkillLevel.label(level),
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            for (var i = 1; i <= SkillLevel.max; i++) ...[
              if (i > 1) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= level ? NawahColors.ink : NawahColors.paperDeep,
                    borderRadius: BorderRadius.circular(NawahRadius.full),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ملاحظة جديدة
// ---------------------------------------------------------------------------

/// يرجع true إن أُضيفت الملاحظة.
Future<bool> showAddNoteSheet(BuildContext context, {required String studentId}) async {
  final added = await showAdaptiveSheet<bool>(context, builder: (_) => _AddNoteSheet(studentId: studentId));
  return added ?? false;
}

class _AddNoteSheet extends StatefulWidget {
  const _AddNoteSheet({required this.studentId});
  final String studentId;

  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  final _body = TextEditingController();
  bool _forGuardian = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'اكتب الملاحظة أولاً.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.addNote(widget.studentId, _body.text, visibleToGuardian: _forGuardian);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHeader(title: 'ملاحظة جديدة', subtitle: 'ما الذي أنجزه الطالب، أو ما يحتاج إليه؟'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NawahSpacing.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _body,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 2000,
                      decoration: const InputDecoration(hintText: 'مثال: برمج اليوم أول حلقة تكرار وحده.'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _forGuardian,
                      onChanged: _busy ? null : (v) => setState(() => _forGuardian = v),
                      title: const Text('يراها ولي الأمر'),
                      subtitle: Text(
                        _forGuardian ? 'تظهر في بوابة الأهل.' : 'للفريق فقط — لا تظهر لولي الأمر.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: NawahSpacing.s2),
                    FormErrorBanner(message: _error),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ الملاحظة'),
                    ),
                    const SizedBox(height: NawahSpacing.s4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// المستويات الخمسة — شرح الإطار
// ---------------------------------------------------------------------------

Future<void> showLevelsLegend(BuildContext context, {required List<({int level, String title, int minPoints})> levels, required int current}) {
  return showAdaptiveSheet<void>(
    context,
    maxWidth: 560,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(
              title: 'كل اختراع يبدأ بنواة',
              subtitle: 'يكتمل وجه الروبوت حول صورة الطالب كلما تقدّم: حضور، وشارات، ومشاريع، ومهارات.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(NawahSpacing.s4, NawahSpacing.s2, NawahSpacing.s4, NawahSpacing.s5),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: NawahSpacing.s4,
                runSpacing: NawahSpacing.s4,
                children: [
                  for (final l in levels)
                    SizedBox(
                      width: 96,
                      child: Column(
                        children: [
                          LevelFrame(
                            level: l.level,
                            size: 64,
                            child: InitialAvatar(
                              initial: '${l.level}',
                              background: l.level == current ? NawahColors.ink : NawahColors.inkTint,
                              foreground: l.level == current ? NawahColors.textInvert : NawahColors.ink,
                            ),
                          ),
                          const SizedBox(height: NawahSpacing.s2),
                          Text(l.title, style: const TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink)),
                          Text('${l.minPoints}+ نقطة', style: const TextStyle(fontSize: 11, color: NawahColors.textMuted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(NawahSpacing.s5, 0, NawahSpacing.s5, NawahSpacing.s5),
              child: Text(
                'النقاط: حضور ١٠ · تأخّر ٥ · شارة حسب نوعها · مشروع ٣٠ · كل درجة مهارة ١٥',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: NawahColors.textMuted, height: 1.7),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
