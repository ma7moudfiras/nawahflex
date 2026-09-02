import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import '../auth/profile.dart';
import '../programs/program.dart';
import '../programs/programs_repository.dart';
import '../students/student.dart';
import '../students/students_repository.dart';
import 'cohort.dart';
import 'cohort_form.dart';
import 'cohorts_repository.dart';

/// شاشة الأفواج — إدارية بالكامل (إدارة/محرّر فقط عبر التنقّل في main.dart،
/// و RLS تمنع أي كتابة من غيرهم على أي حال). إنشاء/تعديل فوج، وتسجيل
/// طلابه، من نفس النموذج.
class CohortsScreen extends StatefulWidget {
  const CohortsScreen({super.key});

  @override
  State<CohortsScreen> createState() => _CohortsScreenState();
}

class _CohortsScreenState extends State<CohortsScreen> {
  final _repo = const CohortsRepository();
  final _programsRepo = const ProgramsRepository();
  final _studentsRepo = const StudentsRepository();

  List<Cohort> _items = [];
  List<Program> _programs = [];
  List<Student> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repo.fetch();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
      // البرامج والطلاب لازمة لنموذج الفوج فقط — فشلها لا يمنع عرض القائمة.
      _programsRepo.fetch().then((p) { if (mounted) setState(() => _programs = p); }).catchError((_) {});
      _studentsRepo.fetch(activeOnly: true).then((s) { if (mounted) setState(() => _students = s); }).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذّر تحميل الأفواج. تحقّق من اتصالك ثم أعد المحاولة.'; });
    }
  }

  Future<void> _openForm({Cohort? existing}) async {
    final trainers = await _repo.fetchTrainers().catchError((_) => const <Profile>[]);
    final initialStudentIds =
        existing == null ? <String>[] : await _repo.fetchEnrolledStudentIds(existing.id);
    if (!mounted) return;

    Future<void> onSubmit(Cohort c, List<String> studentIds) async {
      final id = existing == null ? await _repo.create(c) : existing.id;
      if (existing != null) await _repo.update(existing.id, c);
      await _repo.setEnrolledStudents(id, studentIds);
      await _load();
    }

    final form = CohortForm(
      initial: existing,
      onSubmit: onSubmit,
      programs: _programs,
      trainers: trainers,
      allStudents: _students,
      initialStudentIds: initialStudentIds,
    );

    if (context.isWide) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: form),
        ),
      );
    } else {
      await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => form);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());

    Widget body;
    if (_error != null) {
      body = _Empty(
        icon: Icons.wifi_off,
        title: 'تعذّر التحميل',
        subtitle: _error!,
        action: FilledButton.tonal(onPressed: _load, child: const Text('إعادة المحاولة')),
      );
    } else if (_items.isEmpty) {
      body = const _Empty(
        icon: Icons.groups_2_outlined,
        title: 'لا توجد أفواج بعد',
        subtitle: 'اضغط زر الإضافة لإنشاء أول فوج وإسناد مدرّب وطلاب له.',
      );
    } else {
      final columns = adaptive(context, mobile: 1, tablet: 2, desktop: 3);
      body = RefreshIndicator(
        onRefresh: _load,
        child: GridView.builder(
          padding: const EdgeInsets.all(NawahSpacing.s4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: NawahSpacing.s3,
            crossAxisSpacing: NawahSpacing.s3,
            mainAxisExtent: 170,
          ),
          itemCount: _items.length,
          itemBuilder: (_, i) => _CohortCard(cohort: _items[i], onTap: () => _openForm(existing: _items[i])),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'إضافة فوج',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CohortCard extends StatelessWidget {
  const _CohortCard({required this.cohort, required this.onTap});
  final Cohort cohort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NawahColors.card,
      borderRadius: BorderRadius.circular(NawahRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        child: Container(
          padding: const EdgeInsets.all(NawahSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NawahRadius.md),
            border: Border.all(color: cohort.isActive ? NawahColors.border : NawahColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(cohort.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: NawahColors.ink)),
                  ),
                  if (!cohort.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: NawahColors.bgAlt, borderRadius: BorderRadius.circular(NawahRadius.full)),
                      child: const Text('متوقّف', style: TextStyle(fontSize: 10, color: NawahColors.textMuted)),
                    ),
                ],
              ),
              const SizedBox(height: NawahSpacing.s2),
              if (cohort.programTitle != null)
                Text('البرنامج: ${cohort.programTitle}', style: const TextStyle(color: NawahColors.textSoft, fontSize: 12)),
              if (cohort.trainerName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('المدرّب: ${cohort.trainerName}', style: const TextStyle(color: NawahColors.textSoft, fontSize: 12)),
                ),
              if (cohort.scheduleLabel != null && cohort.scheduleLabel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(cohort.scheduleLabel!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: NawahColors.textMuted, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle, this.action});
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
              Text(title,
                  style: const TextStyle(
                    fontFamily: NawahFonts.display, fontWeight: FontWeight.w700,
                    fontSize: 17, color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s2),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: NawahColors.textSoft, height: 1.7)),
              if (action != null) ...[const SizedBox(height: NawahSpacing.s5), action!],
            ],
          ),
        ),
      );
}
