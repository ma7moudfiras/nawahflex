import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import '../auth/profile.dart';
import '../students/students_repository.dart';
import '../trainers/trainers_repository.dart';

/// نظرة عامة — أرقام سريعة وروابط للمهام الشائعة.
/// الشبكة تتكيّف: عمود على الجوّال، عمودان على اللوحي، أربعة على المكتب.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.counts,
    required this.onGoToMessages,
  });

  final Profile? profile;
  final Map<String, int> counts;
  final VoidCallback onGoToMessages;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _studentsRepo = const StudentsRepository();
  final _trainersRepo = const TrainersRepository();
  int? _studentCount;
  int? _trainerCount;

  @override
  void initState() {
    super.initState();
    // فشل تحميل العدّادين لا يمنع عرض الشاشة — يبقيان فارغين (—) بصمت.
    _studentsRepo.count().then((c) { if (mounted) setState(() => _studentCount = c); }).catchError((_) {});
    _trainersRepo.count().then((c) { if (mounted) setState(() => _trainerCount = c); }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final counts = widget.counts;
    final onGoToMessages = widget.onGoToMessages;
    final cols = adaptive(context, mobile: 1, tablet: 2, desktop: 4);

    return SingleChildScrollView(
      padding: EdgeInsets.all(adaptive(context, mobile: 16.0, desktop: 32.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أهلاً ${profile?.displayName ?? ''}',
              style: const TextStyle(
                fontFamily: NawahFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: NawahColors.ink,
              )),
          const SizedBox(height: 4),
          const Text('ملخّص سريع لما يحتاج انتباهك اليوم.',
              style: TextStyle(color: NawahColors.textSoft)),
          const SizedBox(height: NawahSpacing.s6),

          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: NawahSpacing.s4,
            mainAxisSpacing: NawahSpacing.s4,
            childAspectRatio:
                adaptive(context, mobile: 3.4, tablet: 2.1, desktop: 1.7),
            children: [
              _Stat(
                icon: Icons.mark_email_unread_outlined,
                tone: NawahColors.accent,
                value: '${counts['new'] ?? 0}',
                label: 'رسالة جديدة',
                onTap: onGoToMessages,
              ),
              _Stat(
                icon: Icons.pending_actions_outlined,
                tone: NawahColors.primary,
                value: '${counts['in_progress'] ?? 0}',
                label: 'قيد المتابعة',
                onTap: onGoToMessages,
              ),
              _Stat(
                icon: Icons.task_alt,
                tone: NawahColors.green,
                value: '${counts['done'] ?? 0}',
                label: 'مكتملة',
                onTap: onGoToMessages,
              ),
              _Stat(
                icon: Icons.all_inbox_outlined,
                tone: NawahColors.violet,
                value: '${counts['all'] ?? 0}',
                label: 'إجمالي الرسائل',
                onTap: onGoToMessages,
              ),
            ],
          ),

          const SizedBox(height: NawahSpacing.s6),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: NawahSpacing.s4,
            mainAxisSpacing: NawahSpacing.s4,
            childAspectRatio:
                adaptive(context, mobile: 3.4, tablet: 2.1, desktop: 1.7),
            children: [
              _Stat(
                icon: Icons.groups_outlined,
                tone: NawahColors.cyan,
                value: _studentCount == null ? '—' : '$_studentCount',
                label: 'طالب مسجَّل',
              ),
              _Stat(
                icon: Icons.badge_outlined,
                tone: NawahColors.primaryDark,
                value: _trainerCount == null ? '—' : '$_trainerCount',
                label: 'مدرّب',
              ),
              _Stat(
                icon: Icons.receipt_long_outlined,
                tone: NawahColors.textMuted,
                value: 'قريباً',
                label: 'المستحقات — سجلّ الدفعات',
              ),
            ],
          ),

          const SizedBox(height: NawahSpacing.s7),
          Container(
            padding: const EdgeInsets.all(NawahSpacing.s5),
            decoration: BoxDecoration(
              color: NawahColors.bgAlt,
              borderRadius: BorderRadius.circular(NawahRadius.md),
              border: Border.all(color: NawahColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.construction_outlined,
                      size: 18, color: NawahColors.textSoft),
                  SizedBox(width: 8),
                  Text('قيد البناء',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: NawahColors.ink)),
                ]),
                SizedBox(height: NawahSpacing.s3),
                Text(
                  'الرسائل والطلاب والبرامج والمدرّبون والأفواج والحضور جاهزة وتعمل. '
                  'الشهادات، حسابات أولياء الأمور، وسجلّ المستحقات (مين دفع ومين لا) '
                  'هي المرحلة التالية — لم تُبنَ بعد.',
                  style: TextStyle(color: NawahColors.textSoft, height: 1.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color tone;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NawahColors.card,
      borderRadius: BorderRadius.circular(NawahRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        child: Container(
          padding: const EdgeInsets.all(NawahSpacing.s5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NawahRadius.md),
            border: Border.all(color: NawahColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(NawahRadius.sm),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    height: 1.1,
                    color: NawahColors.ink,
                  )),
              Text(label,
                  style:
                      const TextStyle(color: NawahColors.textSoft, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
