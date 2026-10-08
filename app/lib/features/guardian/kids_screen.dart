import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../brand/level_frame.dart';
import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../shared/section_card.dart';
import '../auth/change_password_dialog.dart';
import '../auth/profile.dart';
import '../progress/progress_models.dart';
import '../progress/progress_repository.dart';
import '../students/student.dart';
import 'guardian_repository.dart';

/// رئيسية ولي الأمر — «أبنائي»: بطاقة لكل ابن بإطار مستواه، والطريق إلى
/// المستوى التالي، ونسبة حضوره، وآخر ملاحظة من المدرّب. كلها في تحميل واحد.
class KidsScreen extends StatefulWidget {
  const KidsScreen({super.key, required this.viewer});
  final Profile viewer;

  @override
  State<KidsScreen> createState() => _KidsScreenState();
}

class _KidsScreenState extends State<KidsScreen> {
  static const _guardian = GuardianRepository();
  static const _progress = ProgressRepository();

  List<Student>? _kids;
  Map<String, StudentProgress> _prog = const {};
  Map<String, String> _notes = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final kids = await _guardian.fetchChildren();
      final ids = kids.map((k) => k.id).toList();
      final r = await Future.wait<Object>([
        _progress.fetchProgress(ids),
        _guardian.fetchLatestNotes(ids),
      ]);
      if (!mounted) return;
      setState(() {
        _kids = kids;
        _prog = r[0] as Map<String, StudentProgress>;
        _notes = r[1] as Map<String, String>;
      });
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    }
  }

  /// دخل برابط الدعوة ولم يضبط كلمة مرور بعد — بدونها يحتاج رابطاً جديداً كل مرة.
  bool get _needsPassword => Db.user?.userMetadata?['password_set'] != true;

  @override
  Widget build(BuildContext context) {
    final kids = _kids;
    final Widget body;
    if (_error != null && kids == null) {
      body = _Centered(
        icon: Icons.wifi_off,
        text: _error!,
        action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 18), label: const Text('إعادة المحاولة')),
      );
    } else if (kids == null) {
      body = const Column(children: [
        SkeletonBox(height: 168, radius: NawahRadius.lg),
        SizedBox(height: NawahSpacing.s4),
        SkeletonBox(height: 168, radius: NawahRadius.lg),
      ]);
    } else if (kids.isEmpty) {
      body = const _Centered(
        icon: Icons.family_restroom_outlined,
        text: 'لم يُربط أي طالب بحسابك بعد.\nتواصل مع الأكاديمية ليُضاف أبناؤك.',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in kids) ...[
            _KidCard(
              kid: k,
              progress: _prog[k.id] ?? StudentProgress.empty(k.id),
              note: _notes[k.id],
              onOpen: () => context.push('/kids/${k.id}'),
            ),
            const SizedBox(height: NawahSpacing.s4),
          ],
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(NawahSpacing.s4, NawahSpacing.s4, NawahSpacing.s4, NawahSpacing.s7),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أهلاً ${widget.viewer.displayName}',
                  style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 22, color: NawahColors.ink),
                ),
                const SizedBox(height: NawahSpacing.s1),
                const Text('تقدّم أبنائك في الأكاديمية، أولاً بأول.', style: TextStyle(color: NawahColors.textMuted)),
                const SizedBox(height: NawahSpacing.s5),
                if (_needsPassword) ...[
                  _PasswordNudge(onSet: () async {
                    await showChangePasswordSheet(context);
                    if (mounted) setState(() {});
                  }),
                  const SizedBox(height: NawahSpacing.s4),
                ],
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KidCard extends StatelessWidget {
  const _KidCard({required this.kid, required this.progress, required this.onOpen, this.note});
  final Student kid;
  final StudentProgress progress;
  final String? note;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final rate = p.attendanceRate;
    return Material(
      color: NawahColors.card,
      borderRadius: BorderRadius.circular(NawahRadius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(NawahRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(NawahSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NawahRadius.lg),
            border: Border.all(color: NawahColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LevelFrame(
                    level: p.level,
                    size: 68,
                    background: NawahColors.card,
                    child: InitialAvatar(initial: kid.initial),
                  ),
                  const SizedBox(width: NawahSpacing.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kid.fullName,
                          style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
                        ),
                        if (kid.programTitles.isNotEmpty)
                          Text(kid.programTitles.join(' · '), style: const TextStyle(color: NawahColors.textMuted, fontSize: 13)),
                        const SizedBox(height: NawahSpacing.s2),
                        Wrap(
                          spacing: NawahSpacing.s2,
                          runSpacing: NawahSpacing.s1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(color: NawahColors.accent, borderRadius: BorderRadius.circular(NawahRadius.full)),
                              child: Text('المستوى ${p.level} · ${p.levelTitle}',
                                  style: const TextStyle(color: NawahColors.onAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                            Text('${p.points} نقطة', style: const TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: NawahColors.textMuted),
                ],
              ),
              const SizedBox(height: NawahSpacing.s3),
              ClipRRect(
                borderRadius: BorderRadius.circular(NawahRadius.full),
                child: LinearProgressIndicator(
                  value: p.levelFraction,
                  minHeight: 6,
                  color: NawahColors.accent,
                  backgroundColor: NawahColors.paperDeep,
                ),
              ),
              const SizedBox(height: NawahSpacing.s2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.isMaxLevel ? 'أعلى مستوى — اكتمل وجه الروبوت.' : '${p.pointsToNext} نقطة إلى المستوى التالي',
                      style: const TextStyle(fontSize: 12, color: NawahColors.textMuted),
                    ),
                  ),
                  if (rate != null)
                    Text('الحضور $rate%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NawahColors.ink)),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: NawahSpacing.s3),
                Container(
                  padding: const EdgeInsets.all(NawahSpacing.s3),
                  decoration: BoxDecoration(color: NawahColors.paper, borderRadius: BorderRadius.circular(NawahRadius.sm)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 18, color: NawahColors.textMuted),
                      const SizedBox(width: NawahSpacing.s2),
                      Expanded(
                        child: Text(note!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.7, color: NawahColors.text)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordNudge extends StatelessWidget {
  const _PasswordNudge({required this.onSet});
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'اضبط كلمة مرور',
      icon: Icons.key_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'دخلت برابط الدعوة، وهو يُستعمل مرة واحدة. اضبط كلمة مرور لتدخل لاحقاً ببريدك وكلمة المرور.',
            style: TextStyle(color: NawahColors.textSoft, height: 1.7, fontSize: 13),
          ),
          const SizedBox(height: NawahSpacing.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(onPressed: onSet, child: const Text('ضبط كلمة المرور')),
          ),
        ],
      ),
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
