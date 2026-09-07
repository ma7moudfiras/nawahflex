import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import '../../shared/money.dart';
import 'trainer_payroll.dart';
import 'trainer_payroll_repository.dart';

/// شاشة مستحقات المدرّبين — الساعات والمبلغ محسوبان من حصصهم المسجَّلة
/// فعلياً بذلك الشهر، كلٌّ بسعره الملتقَط وقتها. تسديد/إلغاء تسديد
/// يُسجَّل كحدث جديد دائماً (سجلّ لا استبدال).
class TrainerPayrollScreen extends StatefulWidget {
  const TrainerPayrollScreen({super.key});

  @override
  State<TrainerPayrollScreen> createState() => _TrainerPayrollScreenState();
}

class _TrainerPayrollScreenState extends State<TrainerPayrollScreen> {
  final _repo = const TrainerPayrollRepository();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<TrainerPayroll> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchAll(_month);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل المستحقات. تحقّق من اتصالك ثم أعد المحاولة.';
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  static const _monthNames = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  String get _monthLabel => '${_monthNames[_month.month - 1]} ${_month.year}';

  Future<void> _togglePaid(TrainerPayroll item) async {
    await _repo.setPayoutStatus(item.trainerId, _month, !item.isPaid);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(NawahSpacing.s4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Text(
                  _monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: NawahColors.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _Empty(
                  icon: Icons.wifi_off,
                  title: 'تعذّر التحميل',
                  subtitle: _error!,
                  action: FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                )
              : _items.isEmpty
              ? const _Empty(
                  icon: Icons.badge_outlined,
                  title: 'لا يوجد مدرّبون بحسابات دخول بعد',
                  subtitle: 'اربط حساب دخول بمدرّب من شاشة المدرّبين أولاً.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.all(
                      adaptive(context, mobile: 16.0, desktop: 32.0),
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: NawahSpacing.s2),
                    itemBuilder: (_, i) => _PayrollRow(
                      item: _items[i],
                      onTogglePaid: () => _togglePaid(_items[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PayrollRow extends StatelessWidget {
  const _PayrollRow({required this.item, required this.onTogglePaid});
  final TrainerPayroll item;
  final VoidCallback onTogglePaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NawahSpacing.s3),
      decoration: BoxDecoration(
        color: NawahColors.card,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        border: Border.all(color: NawahColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NawahColors.ink,
                  ),
                ),
                Text(
                  '${item.hours.toStringAsFixed(item.hours == item.hours.roundToDouble() ? 0 : 1)} ساعة · ${formatMoney(item.amount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: NawahColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          FilterChip(
            label: Text(item.isPaid ? 'مسدَّد' : 'غير مسدَّد'),
            selected: item.isPaid,
            onSelected: (_) => onTogglePaid(),
            selectedColor: NawahColors.green.withValues(alpha: .18),
            labelStyle: TextStyle(
              color: item.isPaid ? NawahColors.green : NawahColors.textSoft,
              fontWeight: FontWeight.w700,
            ),
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
