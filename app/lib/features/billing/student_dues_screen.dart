import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import '../../shared/money.dart';
import 'billing_repository.dart';
import 'student_due.dart';

/// شاشة المستحقات — نظرة شهرية على كل الطلاب النشطين: مين مسدَّد، مين
/// جزئي، ومين لسه ما دفع لهذا الشهر. الضغط على طالب يفتح تفاصيله
/// (توليد استحقاق، تسجيل دفعة، تفعيل خصم الإخوة).
class StudentDuesScreen extends StatefulWidget {
  const StudentDuesScreen({super.key});

  @override
  State<StudentDuesScreen> createState() => _StudentDuesScreenState();
}

class _StudentDuesScreenState extends State<StudentDuesScreen> {
  final _repo = const BillingRepository();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<StudentDueOverview> _items = [];
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
      final items = await _repo.fetchOverview(_month);
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

  Future<void> _openDetail(StudentDueOverview item) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _StudentDueDetail(
            item: item,
            month: _month,
            repo: _repo,
            onChanged: _load,
          ),
        ),
      ),
    );
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
                  icon: Icons.groups_outlined,
                  title: 'لا يوجد طلاب نشطون',
                  subtitle: 'أضف طلاباً من شاشة الطلاب أولاً.',
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
                    itemBuilder: (_, i) => _DueRow(
                      item: _items[i],
                      onTap: () => _openDetail(_items[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.item, required this.onTap});
  final StudentDueOverview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final String badgeLabel;
    if (item.isFullyPaid) {
      badgeColor = NawahColors.green;
      badgeLabel = 'مسدَّد';
    } else if (item.isPartiallyPaid) {
      badgeColor = NawahColors.accent;
      badgeLabel = 'جزئي';
    } else {
      badgeColor = NawahColors.rose;
      badgeLabel = 'غير مسدَّد';
    }

    return Material(
      color: NawahColors.card,
      borderRadius: BorderRadius.circular(NawahRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        child: Container(
          padding: const EdgeInsets.all(NawahSpacing.s3),
          decoration: BoxDecoration(
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
                      item.hasDue
                          ? '${formatMoney(item.paidTotal)} من ${formatMoney(item.due!.amountDue)}'
                          : 'متوقَّع: ${formatMoney(item.expectedAmount)} (لم يُوَلَّد بعد)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NawahColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(NawahRadius.full),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentDueDetail extends StatefulWidget {
  const _StudentDueDetail({
    required this.item,
    required this.month,
    required this.repo,
    required this.onChanged,
  });
  final StudentDueOverview item;
  final DateTime month;
  final BillingRepository repo;
  final VoidCallback onChanged;

  @override
  State<_StudentDueDetail> createState() => _StudentDueDetailState();
}

class _StudentDueDetailState extends State<_StudentDueDetail> {
  late StudentDueOverview _item;
  late bool _siblingDiscount;
  List<StudentPayment> _payments = [];
  bool _busy = false;
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _siblingDiscount = widget.item.siblingDiscount;
    if (_item.hasDue) _loadPayments();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    final due = _item.due;
    if (due == null) return;
    final payments = await widget.repo.fetchPayments(due.id);
    if (mounted) setState(() => _payments = payments);
  }

  Future<void> _generateDue() async {
    setState(() => _busy = true);
    try {
      final due = await widget.repo.ensureDue(_item.studentId, widget.month);
      if (!mounted) return;
      setState(
        () => _item = StudentDueOverview(
          studentId: _item.studentId,
          fullName: _item.fullName,
          expectedAmount: _item.expectedAmount,
          siblingDiscount: _item.siblingDiscount,
          due: due,
        ),
      );
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSibling(bool enabled) async {
    setState(() => _busy = true);
    try {
      await widget.repo.setSiblingDiscount(_item.studentId, enabled);
      if (mounted) setState(() => _siblingDiscount = enabled);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled ? 'فُعِّل خصم الإخوة' : 'أُلغي خصم الإخوة'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPayment() async {
    final due = _item.due;
    final amount = double.tryParse(_amount.text.trim());
    if (due == null || amount == null || amount <= 0) return;
    setState(() => _busy = true);
    try {
      await widget.repo.recordPayment(
        dueId: due.id,
        amount: amount,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      _amount.clear();
      _note.clear();
      await _loadPayments();
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = _item.due;
    return Padding(
      padding: const EdgeInsets.all(NawahSpacing.s5),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _item.fullName,
              style: const TextStyle(
                fontFamily: NawahFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: NawahColors.ink,
              ),
            ),
            const SizedBox(height: NawahSpacing.s4),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('خصم الإخوة'),
              value: _siblingDiscount,
              onChanged: _busy ? null : _toggleSibling,
            ),

            const Divider(height: NawahSpacing.s5),

            if (due == null) ...[
              Text(
                'لم يُنشأ استحقاق لهذا الشهر بعد. المتوقَّع: ${formatMoney(_item.expectedAmount)}',
                style: const TextStyle(color: NawahColors.textSoft),
              ),
              const SizedBox(height: NawahSpacing.s3),
              FilledButton(
                onPressed: _busy ? null : _generateDue,
                child: const Text('توليد استحقاق الشهر'),
              ),
            ] else ...[
              Text(
                'المبلغ المستحَق: ${formatMoney(due.amountDue)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: NawahColors.ink,
                ),
              ),
              Text(
                'المدفوع: ${formatMoney(_item.paidTotal)} · المتبقّي: ${formatMoney(_item.balance < 0 ? 0 : _item.balance)}',
                style: const TextStyle(
                  color: NawahColors.textSoft,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: NawahSpacing.s4),

              if (_payments.isNotEmpty) ...[
                const Text(
                  'الدفعات',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NawahColors.textSoft,
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                ..._payments.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${formatMoney(p.amount)} — ${p.paidAt.year}/${p.paidAt.month}/${p.paidAt.day}'
                      '${p.note != null && p.note!.isNotEmpty ? ' (${p.note})' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NawahColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NawahSpacing.s3),
              ],

              if (_item.balance > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'مبلغ الدفعة',
                        ),
                      ),
                    ),
                    const SizedBox(width: NawahSpacing.s2),
                    Expanded(
                      child: TextField(
                        controller: _note,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NawahSpacing.s3),
                FilledButton(
                  onPressed: _busy ? null : _recordPayment,
                  child: const Text('تسجيل دفعة'),
                ),
              ] else
                const Text(
                  'تم السداد بالكامل',
                  style: TextStyle(
                    color: NawahColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ],
        ),
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
