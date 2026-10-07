import 'package:flutter/material.dart';

import '../../brand/level_frame.dart';
import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../shared/section_card.dart';
import '../auth/profile.dart';
import '../progress/progress_models.dart';
import '../progress/progress_repository.dart';
import '../progress/progress_sheets.dart';
import '../progress/projects_card.dart';
import '../students/student.dart';
import 'student_account_repository.dart';

typedef _Level = ({int level, String title, int minPoints});

/// «ملفّي» — رئيسية الطالب. تحفيزية لا إدارية: إطاره كبيراً، كم بقي للمستوى
/// التالي، شاراته المنالة والمقفلة (أهداف يراها)، ومهاراته. لا ملاحظات ولا مالية.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, required this.viewer});
  final Profile viewer;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _Data {
  const _Data(this.me, this.progress, this.levels, this.catalog, this.earned, this.skills, this.skillLevels, this.projects);
  final Student me;
  final StudentProgress progress;
  final List<_Level> levels;
  final List<BadgeDef> catalog;
  final List<EarnedBadge> earned;
  final List<Skill> skills;
  final Map<String, int> skillLevels;
  final List<StudentProject> projects;
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  static const _account = StudentAccountRepository();
  static const _progress = ProgressRepository();

  _Data? _data;
  String? _error;
  bool _unlinked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final me = await _account.fetchMe();
      if (me == null) {
        if (mounted) setState(() => _unlinked = true);
        return;
      }
      final r = await Future.wait<Object>([
        _progress.fetchOne(me.id),
        _progress.fetchLevels(),
        _progress.fetchBadgeCatalog(),
        _progress.fetchEarnedBadges(me.id),
        _progress.fetchSkills(me.programIds),
        _progress.fetchSkillLevels(me.id),
        _progress.fetchProjects(me.id),
      ]);
      if (!mounted) return;
      setState(() => _data = _Data(
            me,
            r[0] as StudentProgress,
            r[1] as List<_Level>,
            r[2] as List<BadgeDef>,
            r[3] as List<EarnedBadge>,
            r[4] as List<Skill>,
            r[5] as Map<String, int>,
            r[6] as List<StudentProject>,
          ));
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_unlinked) {
      body = const _Centered(icon: Icons.link_off, text: 'حسابك غير مربوط بملف طالب بعد. تواصل مع الأكاديمية.');
    } else if (_error != null && _data == null) {
      body = _Centered(
        icon: Icons.wifi_off,
        text: _error!,
        action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 18), label: const Text('إعادة المحاولة')),
      );
    } else if (_data == null) {
      body = const Column(children: [
        SkeletonBox(height: 260, radius: NawahRadius.lg),
        SizedBox(height: NawahSpacing.s4),
        SkeletonBox(height: 180, radius: NawahRadius.md),
      ]);
    } else {
      body = _content(_data!);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(NawahSpacing.s4, NawahSpacing.s4, NawahSpacing.s4, NawahSpacing.s7),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
        ),
      ),
    );
  }

  Widget _content(_Data d) {
    final p = d.progress;
    final next = d.levels.where((l) => l.level == p.level + 1).firstOrNull;
    final earnedIds = d.earned.map((e) => e.badgeId).toSet();
    final relevant = d.catalog
        .where((b) => b.isActive || earnedIds.contains(b.id))
        .where((b) => b.programId == null || d.me.programIds.contains(b.programId))
        .toList()
      ..sort((a, b) => (earnedIds.contains(a.id) ? 0 : 1).compareTo(earnedIds.contains(b.id) ? 0 : 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- الإطار والمستوى ----
        Container(
          padding: const EdgeInsets.all(NawahSpacing.s5),
          decoration: BoxDecoration(color: NawahColors.ink, borderRadius: BorderRadius.circular(NawahRadius.lg)),
          child: Column(
            children: [
              InkWell(
                onTap: () => showLevelsLegend(context, levels: d.levels, current: p.level),
                borderRadius: BorderRadius.circular(NawahRadius.md),
                child: LevelFrame(
                  level: p.level,
                  size: 128,
                  color: NawahColors.textInvert,
                  background: NawahColors.ink,
                  child: InitialAvatar(initial: d.me.initial, background: NawahColors.inkSoft, foreground: NawahColors.textInvert),
                ),
              ),
              const SizedBox(height: NawahSpacing.s3),
              Text(
                'أهلاً ${d.me.fullName.split(' ').first}',
                style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 24, color: NawahColors.textInvert),
              ),
              const SizedBox(height: NawahSpacing.s2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: NawahColors.accent, borderRadius: BorderRadius.circular(NawahRadius.full)),
                child: Text('المستوى ${p.level} · ${p.levelTitle}',
                    style: const TextStyle(color: NawahColors.onAccent, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: NawahSpacing.s4),
              ClipRRect(
                borderRadius: BorderRadius.circular(NawahRadius.full),
                child: LinearProgressIndicator(
                  value: p.levelFraction,
                  minHeight: 10,
                  color: NawahColors.accent,
                  backgroundColor: NawahColors.inkLine,
                ),
              ),
              const SizedBox(height: NawahSpacing.s2),
              Text(
                p.isMaxLevel
                    ? 'اكتمل وجه الروبوت — أنت مخترع!'
                    : 'معك ${p.points} نقطة — بقي ${p.pointsToNext} لتصير «${next?.title ?? 'المستوى التالي'}»',
                textAlign: TextAlign.center,
                style: const TextStyle(color: NawahColors.invertSoft, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: NawahSpacing.s3),
        const Text(
          'تكسب النقاط بالحضور، والشارات، والمشاريع، وتطوّر مهاراتك.',
          textAlign: TextAlign.center,
          style: TextStyle(color: NawahColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: NawahSpacing.s4),

        // ---- الشارات: المنالة ثم المقفلة ----
        SectionCard(
          title: 'شاراتي (${earnedIds.length} من ${relevant.length})',
          icon: Icons.military_tech_outlined,
          child: relevant.isEmpty
              ? const Text('لا شارات بعد.', style: TextStyle(color: NawahColors.textMuted))
              : LayoutBuilder(
                  builder: (context, box) {
                    final perRow = box.maxWidth < 420 ? 3 : 5;
                    final w = (box.maxWidth - NawahSpacing.s3 * (perRow - 1)) / perRow;
                    return Wrap(
                      spacing: NawahSpacing.s3,
                      runSpacing: NawahSpacing.s4,
                      children: [
                        for (final b in relevant)
                          SizedBox(
                            width: w,
                            child: Tooltip(
                              message: b.description,
                              child: Column(
                                children: [
                                  BadgeDisc(icon: b.icon, size: 52, muted: !earnedIds.contains(b.id)),
                                  const SizedBox(height: NawahSpacing.s1),
                                  Text(
                                    b.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: earnedIds.contains(b.id) ? NawahColors.ink : NawahColors.textMuted,
                                    ),
                                  ),
                                  if (!earnedIds.contains(b.id))
                                    Text('+${b.points}', style: const TextStyle(fontSize: 11, color: NawahColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: NawahSpacing.s4),

        ProjectsCard(
          title: 'مشاريعي',
          studentId: d.me.id,
          projects: d.projects,
          canEdit: false,
          onChanged: _load,
        ),
        const SizedBox(height: NawahSpacing.s4),

        // ---- المهارات ----
        SectionCard(
          title: 'مهاراتي',
          icon: Icons.insights_outlined,
          child: d.skills.isEmpty
              ? const Text('يحدّد مدرّبك مهاراتك قريباً.', style: TextStyle(color: NawahColors.textMuted))
              : Column(
                  children: [
                    for (final s in d.skills)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: NawahSpacing.s2),
                        child: Row(
                          children: [
                            Expanded(child: Text(s.title)),
                            SkillMeter(level: d.skillLevels[s.id] ?? 0, width: 72),
                            const SizedBox(width: NawahSpacing.s2),
                            SizedBox(
                              width: 52,
                              child: Text(
                                d.skillLevels[s.id] == null ? '—' : SkillLevel.label(d.skillLevels[s.id]!),
                                style: const TextStyle(fontSize: 12, color: NawahColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: NawahSpacing.s7),
        child: Column(
          children: [
            Icon(icon, size: 48, color: NawahColors.textMuted),
            const SizedBox(height: NawahSpacing.s3),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: NawahColors.textSoft, height: 1.8)),
            if (action != null) ...[const SizedBox(height: NawahSpacing.s4), action!],
          ],
        ),
      );
}
