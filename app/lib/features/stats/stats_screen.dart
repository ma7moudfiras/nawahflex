import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import 'stat_form.dart';
import 'stat_item.dart';
import 'stats_repository.dart';

/// شاشة الإحصائيات — بطاقات الهيرو بالموقع التعريفي (طالب، مدرّب، شريك...).
/// الموقع يقرأ من نفس هذا الجدول مباشرة، فأي حفظ هنا ينعكس عليه فوراً.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _repo = const StatsRepository();
  List<StatItem> _items = [];
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
      setState(() { _loading = false; _error = 'تعذّر تحميل الإحصائيات. تحقّق من اتصالك ثم أعد المحاولة.'; });
    }
  }

  Future<void> _openForm({StatItem? existing}) async {
    Future<void> onSubmit(StatItem s) async {
      if (existing == null) {
        await _repo.create(s);
      } else {
        await _repo.update(existing.id, s);
      }
      await _load();
    }

    final form = StatForm(initial: existing, onSubmit: onSubmit);

    if (context.isWide) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form),
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
        icon: Icons.bar_chart_outlined,
        title: 'لا توجد بطاقات إحصاء بعد',
        subtitle: 'اضغط زر الإضافة لإنشاء أول بطاقة.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: EdgeInsets.all(adaptive(context, mobile: 16.0, desktop: 32.0)),
          itemCount: _items.length,
          separatorBuilder: (_, _) => const SizedBox(height: NawahSpacing.s3),
          itemBuilder: (_, i) => _StatRow(stat: _items[i], onTap: () => _openForm(existing: _items[i])),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'إضافة بطاقة',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat, required this.onTap});
  final StatItem stat;
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
          child: Row(
            children: [
              Text(stat.icon ?? '📊', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: NawahSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stat.value}${stat.suffix}',
                        style: const TextStyle(
                          fontFamily: NawahFonts.display, fontWeight: FontWeight.w800,
                          fontSize: 20, color: NawahColors.ink,
                        )),
                    Text(stat.label, style: const TextStyle(color: NawahColors.textSoft, fontSize: 13)),
                  ],
                ),
              ),
              if (!stat.isPublished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: NawahColors.bgAlt, borderRadius: BorderRadius.circular(NawahRadius.full)),
                  child: const Text('مسودة', style: TextStyle(fontSize: 11, color: NawahColors.textMuted)),
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
