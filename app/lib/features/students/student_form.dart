import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/months.dart';
import '../billing/billing_repository.dart';
import '../programs/program.dart';
import 'student.dart';

/// نموذج إضافة/تعديل طالب — يُفتح كـ bottom sheet على الجوّال وحوار على الأوسع،
/// القرار يتّخذه المستدعي عبر showModalBottomSheet أو showDialog حسب الحجم.
class StudentForm extends StatefulWidget {
  const StudentForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.allPrograms = const [],
    this.initialProgramIds = const [],
  });

  final Student? initial;
  final Future<void> Function(Student student, List<String> programIds)
  onSubmit;

  /// كتالوج البرامج للاختيار المتعدد. قائمة فارغة تُخفي القسم بالكامل —
  /// لا حاجة لإجبار الشاشات الأخرى على تحميل البرامج قبل استعمال النموذج.
  final List<Program> allPrograms;
  final List<String> initialProgramIds;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _form = GlobalKey<FormState>();
  final _billingRepo = const BillingRepository();
  late final TextEditingController _name;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianPhone;
  late final TextEditingController _guardianEmail;
  late final TextEditingController _notes;
  DateTime? _birthDate;
  String? _gender;
  late Set<String> _selectedProgramIds;
  bool _busy = false;

  DateTime? _billingStartMonth;
  int _monthsYear = DateTime.now().year;
  Map<int, bool> _monthOverrides = {};
  bool _loadingMonths = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _name = TextEditingController(text: s?.fullName ?? '');
    _guardianName = TextEditingController(text: s?.guardianName ?? '');
    _guardianPhone = TextEditingController(text: s?.guardianPhone ?? '');
    _guardianEmail = TextEditingController(text: s?.guardianEmail ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _birthDate = s?.birthDate;
    _gender = s?.gender;
    _selectedProgramIds = widget.initialProgramIds.toSet();
    _billingStartMonth = s?.billingStartMonth;
    if (_editing) _loadMonthOverrides();
  }

  Future<void> _loadMonthOverrides() async {
    setState(() => _loadingMonths = true);
    try {
      final overrides = await _billingRepo.fetchMonthOverrides(
        widget.initial!.id,
        _monthsYear,
      );
      if (!mounted) return;
      setState(() {
        _monthOverrides = overrides;
        _loadingMonths = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMonths = false);
    }
  }

  void _changeMonthsYear(int delta) {
    setState(() => _monthsYear += delta);
    _loadMonthOverrides();
  }

  /// هل الطالب مسجَّل بشهر معيّن افتراضياً (بلا أي تعديل يدوي) — حسب شهر
  /// بداية الاشتراك فقط: كل شهر منه فصاعداً "مسجَّل".
  bool _naturalEnrollment(int month) {
    final start = _billingStartMonth;
    if (start == null) return true;
    final period = DateTime(_monthsYear, month);
    final startMonth = DateTime(start.year, start.month);
    return !period.isBefore(startMonth);
  }

  Future<void> _toggleMonth(int month) async {
    final current = _monthOverrides[month] ?? _naturalEnrollment(month);
    final next = !current;
    final studentId = widget.initial!.id;
    final period = DateTime(_monthsYear, month);
    setState(() => _monthOverrides = {..._monthOverrides, month: next});
    try {
      if (next == _naturalEnrollment(month)) {
        await _billingRepo.clearMonthOverride(studentId, period);
      } else {
        await _billingRepo.setMonthOverride(studentId, period, next);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ تعديل الشهر — حاول مجدداً.')),
      );
      await _loadMonthOverrides();
    }
  }

  Future<void> _pickBillingStartMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _billingStartMonth ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      helpText: 'بداية الاشتراك (الشهر الذي بدأ منه الطالب فعلياً)',
    );
    if (picked != null) {
      setState(() => _billingStartMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _guardianName,
      _guardianPhone,
      _guardianEmail,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 8),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'تاريخ الميلاد',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        Student(
          id: widget.initial?.id ?? '',
          fullName: _name.text.trim(),
          birthDate: _birthDate,
          gender: _gender,
          guardianName: _guardianName.text.trim(),
          guardianPhone: _guardianPhone.text.trim(),
          guardianEmail: _guardianEmail.text.trim(),
          notes: _notes.text.trim(),
          isActive: widget.initial?.isActive ?? true,
          createdAt: widget.initial?.createdAt ?? DateTime.now(),
          billingStartMonth: _billingStartMonth,
        ),
        _selectedProgramIds.toList(),
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
                editing ? 'تعديل بيانات الطالب' : 'طالب جديد',
                style: const TextStyle(
                  fontFamily: NawahFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: NawahColors.ink,
                ),
              ),
              const SizedBox(height: NawahSpacing.s5),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'اسم الطالب الكامل',
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'أدخل اسماً صحيحاً' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickBirthDate,
                      icon: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(
                        _birthDate == null
                            ? 'تاريخ الميلاد'
                            : '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}',
                      ),
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s3),
                  DropdownButton<String?>(
                    value: _gender,
                    hint: const Text('الجنس'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('—')),
                      DropdownMenuItem(value: 'm', child: Text('ذكر')),
                      DropdownMenuItem(value: 'f', child: Text('أنثى')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                ],
              ),
              const SizedBox(height: NawahSpacing.s5),

              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'الاشتراك والمستحقات',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NawahColors.textSoft,
                  ),
                ),
              ),
              const SizedBox(height: NawahSpacing.s2),
              OutlinedButton.icon(
                onPressed: _pickBillingStartMonth,
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: Text(
                  _billingStartMonth == null
                      ? 'بداية الاشتراك'
                      : 'بداية الاشتراك: ${arabicMonthLabel(_billingStartMonth!)}',
                ),
              ),
              if (_editing) ...[
                const SizedBox(height: NawahSpacing.s3),
                Text(
                  'فعّل/عطّل شهراً معيّناً — لتسجيل إجازة الطالب (تعطيل شهر لاحق)، '
                  'أو لتسجيل التزام قديم قبل بداية النظام (تفعيل شهر سابق):',
                  style: const TextStyle(
                    color: NawahColors.textMuted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonthsYear(-1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    Expanded(
                      child: Text(
                        '$_monthsYear',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: NawahColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonthsYear(1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ],
                ),
                if (_loadingMonths)
                  const Padding(
                    padding: EdgeInsets.all(NawahSpacing.s4),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Wrap(
                    spacing: NawahSpacing.s2,
                    runSpacing: NawahSpacing.s2,
                    children: List.generate(12, (i) {
                      final month = i + 1;
                      final enrolled =
                          _monthOverrides[month] ?? _naturalEnrollment(month);
                      final hasOverride = _monthOverrides.containsKey(month);
                      return FilterChip(
                        label: Text(arabicMonthNames[i]),
                        selected: enrolled,
                        onSelected: (_) => _toggleMonth(month),
                        selectedColor: NawahColors.primarySoft,
                        backgroundColor: hasOverride
                            ? NawahColors.accentSoft
                            : null,
                        side: hasOverride
                            ? const BorderSide(color: NawahColors.accent)
                            : null,
                      );
                    }),
                  ),
              ],
              const SizedBox(height: NawahSpacing.s5),

              if (widget.allPrograms.isNotEmpty) ...[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'البرامج المسجَّل بها',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: NawahColors.textSoft,
                    ),
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                Wrap(
                  spacing: NawahSpacing.s2,
                  runSpacing: NawahSpacing.s2,
                  children: widget.allPrograms.map((p) {
                    final selected = _selectedProgramIds.contains(p.id);
                    final age = Student.ageFrom(_birthDate);
                    final outOfRange = age != null && !p.fitsAge(age);
                    final label = p.ageRangeLabel.isEmpty
                        ? p.title
                        : '${p.title} (${p.ageRangeLabel})';
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedProgramIds.add(p.id);
                        } else {
                          _selectedProgramIds.remove(p.id);
                        }
                      }),
                      backgroundColor: outOfRange
                          ? NawahColors.accentSoft
                          : null,
                      selectedColor: outOfRange
                          ? NawahColors.accentSoft
                          : NawahColors.primarySoft,
                      side: outOfRange
                          ? const BorderSide(color: NawahColors.accent)
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: NawahSpacing.s5),
              ],

              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'ولي الأمر',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NawahColors.textSoft,
                  ),
                ),
              ),
              const SizedBox(height: NawahSpacing.s2),
              TextFormField(
                controller: _guardianName,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _guardianEmail,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                ),
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                ),
              ),

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
                    : Text(editing ? 'حفظ التعديلات' : 'إضافة الطالب'),
              ),
              const SizedBox(height: NawahSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }
}
