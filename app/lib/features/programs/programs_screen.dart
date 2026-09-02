import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import 'program.dart';
import 'program_form.dart';
import 'programs_repository.dart';

/// شاشة البرامج — إدارة الكتالوج (الاسم، الوصف، الفئة العمرية) الذي تُختار
/// منه البرامج عند تسجيل طالب. بلا قائمة/تفاصيل منفصلة كشاشة الطلاب — عدد
/// البرامج محدود، فبطاقات بسيطة تكفي.
class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  final _repo = const ProgramsRepository();
  List<Program> _items = [];
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
      setState(() { _loading = false; _error = 'تعذّر تحميل البرامج. تحقّق من اتصالك ثم أعد المحاولة.'; });
    }
  }

  Future<void> _openForm({Program? existing}) async {
    Future<void> onSubmit(Program p) async {
      if (existing == null) {
        await _repo.create(p);
      } else {
        await _repo.update(existing.id, p);
      }
      await _load();
    }

    if (context.isWide) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ProgramForm(initial: existing, onSubmit: onSubmit),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ProgramForm(initial: existing, onSubmit: onSubmit),
      );
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
        icon: Icons.school_outlined,
        title: 'لا توجد برامج بعد',
        subtitle: 'اضغط زر الإضافة لإنشاء أول برنامج — مثلاً «RoboMission Elementary».',
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
          itemBuilder: (_, i) => _ProgramCard(
            program: _items[i],
            onTap: () => _openForm(existing: _items[i]),
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'إضافة برنامج',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onTap});
  final Program program;
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
              Text(program.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: NawahColors.ink)),
              const SizedBox(height: NawahSpacing.s2),
              Expanded(
                child: Text(program.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NawahColors.textSoft, fontSize: 13, height: 1.6)),
              ),
              if (program.ageRangeLabel.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.only(top: NawahSpacing.s2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: NawahColors.bgAlt, borderRadius: BorderRadius.circular(NawahRadius.full)),
                    child: Text(program.ageRangeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
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
