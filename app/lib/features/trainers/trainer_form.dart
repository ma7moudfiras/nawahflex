import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../core/config.dart';
import '../../shared/audit.dart';
import '../auth/profile.dart';
import '../cohorts/cohort.dart';
import 'trainer.dart';

/// نموذج إضافة/تعديل سيرة مدرّب. ربط حساب دخول اختياري من قائمة حسابات
/// role='trainer' غير المربوطة بعد؛ تعيين الفوج المسؤول عنه يبقى من شاشة
/// الأفواج نفسها — هنا عرض فقط لتفادي مصدرَي حقيقة لعمود واحد.
class TrainerForm extends StatefulWidget {
  const TrainerForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.availableAccounts = const [],
    this.responsibleCohorts = const [],
    this.currentHourlyRate,
    this.rateHistory = const [],
  });

  final Trainer? initial;

  /// reason يصل null إن لم يتغيّر السعر أصلاً — المستدعي عندها لا يسجّل
  /// حدثاً جديداً بالسجلّ (تفادي تلويثه بتكرار نفس السعر مع كل حفظ).
  final Future<void> Function(
    Trainer trainer,
    double? hourlyRate,
    String? reason,
  )
  onSubmit;
  final List<Profile> availableAccounts;
  final List<Cohort> responsibleCohorts;

  /// سعر الساعة الحالي — null يعني بلا سعر مضبوط بعد (أو بلا حساب دخول).
  final double? currentHourlyRate;
  final List<TrainerRateChange> rateHistory;

  @override
  State<TrainerForm> createState() => _TrainerFormState();
}

class _TrainerFormState extends State<TrainerForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _title;
  late final TextEditingController _bio;
  late final TextEditingController _hourlyRate;
  late final TextEditingController _rateReason;
  String? _profileId;
  bool _isPublished = true;
  bool _busy = false;
  bool _showRateHistory = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _fullName = TextEditingController(text: t?.fullName ?? '');
    _title = TextEditingController(text: t?.title ?? '');
    _bio = TextEditingController(text: t?.bio ?? '');
    _hourlyRate = TextEditingController(
      text: widget.currentHourlyRate?.toString() ?? '',
    );
    _rateReason = TextEditingController();
    _profileId = t?.profileId;
    _isPublished = t?.isPublished ?? true;
  }

  @override
  void dispose() {
    for (final c in [_fullName, _title, _bio, _hourlyRate, _rateReason]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _rateChanged {
    if (_profileId == null) return false;
    final newRate = double.tryParse(_hourlyRate.text.trim());
    return newRate != null && newRate != widget.currentHourlyRate;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final newRate = _profileId == null
          ? null
          : double.tryParse(_hourlyRate.text.trim());
      final rateChanged = _rateChanged;
      await widget.onSubmit(
        Trainer(
          id: widget.initial?.id ?? '',
          fullName: _fullName.text.trim(),
          profileId: _profileId,
          title: _title.text.trim(),
          bio: _bio.text.trim(),
          isPublished: _isPublished,
          createdAt: widget.initial?.createdAt ?? DateTime.now(),
        ),
        rateChanged ? newRate : null,
        rateChanged && _rateReason.text.trim().isNotEmpty
            ? _rateReason.text.trim()
            : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر الحفظ — تأكّد من اتصالك وحاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: NawahSpacing.s5,
        right: NawahSpacing.s5,
        top: NawahSpacing.s5,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editing ? 'تعديل سيرة مدرّب' : 'مدرّب جديد',
                style: const TextStyle(
                  fontFamily: NawahFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: NawahColors.ink,
                ),
              ),
              const SizedBox(height: NawahSpacing.s5),

              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'أدخل اسماً صحيحاً' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'اللقب/التخصص (اختياري، مثال: مدرّب روبوتات أول)',
                ),
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نبذة تظهر بالموقع (اختياري)',
                ),
              ),
              const SizedBox(height: NawahSpacing.s4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تظهر بالموقع'),
                value: _isPublished,
                onChanged: (v) => setState(() => _isPublished = v),
              ),

              const SizedBox(height: NawahSpacing.s4),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'حساب الدخول للوحة',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NawahColors.textSoft,
                  ),
                ),
              ),
              const SizedBox(height: NawahSpacing.s2),
              if (widget.availableAccounts.isEmpty && _profileId == null)
                Container(
                  padding: const EdgeInsets.all(NawahSpacing.s3),
                  decoration: BoxDecoration(
                    color: NawahColors.bgAlt,
                    borderRadius: BorderRadius.circular(NawahRadius.sm),
                  ),
                  child: const Text(
                    'لا يوجد حساب دخول بصلاحية "مدرّب" متاح للربط بعد. أنشئه أولاً '
                    '(تواصل مع الإدارة)، ثم عد لربطه هنا — بلا حساب لن يظهر هذا المدرّب '
                    'ولا يقدر يسجّل حضور طلابه.',
                    style: TextStyle(
                      color: NawahColors.textSoft,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String?>(
                  initialValue: _profileId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'اربط بحساب دخول (اختياري)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('بلا حساب دخول بعد'),
                    ),
                    ...widget.availableAccounts.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.displayName),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _profileId = v),
                ),

              if (_profileId != null) ...[
                const SizedBox(height: NawahSpacing.s4),
                TextFormField(
                  controller: _hourlyRate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'سعر الساعة (${AppConfig.currencySymbol})',
                    helperText: 'تعديل السعر لا يغيّر مستحقات حصص سُجِّلت سابقاً — يُطبَّق على الحصص الجديدة فقط.',
                    helperMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_rateChanged) ...[
                  const SizedBox(height: NawahSpacing.s3),
                  TextFormField(
                    controller: _rateReason,
                    decoration: const InputDecoration(
                      labelText: 'سبب التعديل (اختياري)',
                      hintText: 'مثال: ترقية بعد سنة خبرة',
                    ),
                  ),
                ],
                if (widget.rateHistory.isNotEmpty) ...[
                  const SizedBox(height: NawahSpacing.s3),
                  InkWell(
                    onTap: () =>
                        setState(() => _showRateHistory = !_showRateHistory),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: NawahSpacing.s1,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showRateHistory
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: NawahColors.textSoft,
                          ),
                          const SizedBox(width: NawahSpacing.s1),
                          Text(
                            _showRateHistory
                                ? 'إخفاء سجلّ تعديلات السعر'
                                : 'سجلّ تعديلات السعر (${widget.rateHistory.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: NawahColors.textSoft,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showRateHistory)
                    Container(
                      padding: const EdgeInsets.all(NawahSpacing.s3),
                      decoration: BoxDecoration(
                        color: NawahColors.bgAlt,
                        borderRadius: BorderRadius.circular(NawahRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final change in widget.rateHistory) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${change.hourlyRate.toStringAsFixed(2)} ${AppConfig.currencySymbol}/ساعة',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        auditLine(
                                          change.changedByName,
                                          change.changedAt,
                                        ),
                                        style: const TextStyle(
                                          color: NawahColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (change.reason != null &&
                                          change.reason!.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            change.reason!,
                                            style: const TextStyle(
                                              color: NawahColors.textSoft,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (change != widget.rateHistory.last)
                              const Divider(height: NawahSpacing.s4),
                          ],
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: NawahSpacing.s4),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'الأفواج المسؤول عنها',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: NawahColors.textSoft,
                    ),
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                if (widget.responsibleCohorts.isEmpty)
                  const Text(
                    'لا يوجد فوج مُسنَد بعد — عيّنه من شاشة الأفواج.',
                    style: TextStyle(
                      color: NawahColors.textMuted,
                      fontSize: 12,
                    ),
                  )
                else
                  Wrap(
                    spacing: NawahSpacing.s2,
                    runSpacing: NawahSpacing.s2,
                    children: widget.responsibleCohorts
                        .map(
                          (c) => Chip(
                            label: Text(
                              c.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: NawahColors.primarySoft,
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
              ],

              const SizedBox(height: NawahSpacing.s6),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(editing ? 'حفظ التعديلات' : 'إضافة المدرّب'),
              ),
              const SizedBox(height: NawahSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }
}
