import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import '../cohorts/cohort.dart';
import 'trainer.dart';
import 'trainer_form.dart';
import 'trainers_repository.dart';

/// شاشة المدرّبين — سِيَر تظهر بالموقع (public.trainers)، مع ربط اختياري
/// بحساب دخول للوحة وعرض الأفواج المسؤول عنها. إدارة/محرّر فقط.
class TrainersScreen extends StatefulWidget {
  const TrainersScreen({super.key});

  @override
  State<TrainersScreen> createState() => _TrainersScreenState();
}

class _TrainersScreenState extends State<TrainersScreen> {
  final _repo = const TrainersRepository();
  List<Trainer> _items = [];
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
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذّر تحميل المدرّبين. تحقّق من اتصالك ثم أعد المحاولة.'; });
    }
  }

  Future<void> _openForm({Trainer? existing}) async {
    final accounts = await _repo.fetchAvailableTrainerAccounts(excludingTrainerId: existing?.id);
    final responsibleCohorts = existing?.profileId == null
        ? const <Cohort>[]
        : await _repo.fetchResponsibleCohorts(existing!.profileId!);
    if (!mounted) return;

    Future<void> onSubmit(Trainer t) async {
      if (existing == null) {
        await _repo.create(t);
      } else {
        await _repo.update(existing.id, t);
      }
      await _load();
    }

    final form = TrainerForm(
      initial: existing,
      onSubmit: onSubmit,
      availableAccounts: accounts,
      responsibleCohorts: responsibleCohorts,
    );

    if (context.isWide) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: form),
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
        icon: Icons.badge_outlined,
        title: 'لا يوجد مدرّبون بعد',
        subtitle: 'اضغط زر الإضافة لإضافة أول مدرّب.',
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
            mainAxisExtent: 150,
          ),
          itemCount: _items.length,
          itemBuilder: (_, i) => _TrainerCard(trainer: _items[i], onTap: () => _openForm(existing: _items[i])),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'إضافة مدرّب',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.trainer, required this.onTap});
  final Trainer trainer;
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
            border: Border.all(color: NawahColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(trainer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: NawahColors.ink)),
                  ),
                  Icon(
                    trainer.hasAccount ? Icons.verified_user_outlined : Icons.person_off_outlined,
                    size: 16,
                    color: trainer.hasAccount ? NawahColors.green : NawahColors.textMuted,
                  ),
                ],
              ),
              if (trainer.title != null && trainer.title!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(trainer.title!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: NawahColors.textSoft, fontSize: 12)),
                ),
              const SizedBox(height: NawahSpacing.s2),
              Expanded(
                child: Text(trainer.bio ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NawahColors.textMuted, fontSize: 12, height: 1.6)),
              ),
              Text(trainer.hasAccount ? 'مرتبط بحساب دخول' : 'بلا حساب دخول',
                  style: TextStyle(fontSize: 11, color: trainer.hasAccount ? NawahColors.green : NawahColors.textMuted)),
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
