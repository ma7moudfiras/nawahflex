import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../auth/profile.dart';
import '../programs/program.dart';
import '../students/student.dart';
import 'cohort.dart';

/// نموذج إضافة/تعديل فوج — يشمل إسناد البرنامج والمدرّب، وتسجيل الطلاب
/// (اختيار متعدد) مباشرة من نفس النموذج، بنفس نمط اختيار البرامج في
/// StudentForm.
class CohortForm extends StatefulWidget {
  const CohortForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.programs = const [],
    this.trainers = const [],
    this.allStudents = const [],
    this.initialStudentIds = const [],
  });

  final Cohort? initial;
  final Future<void> Function(Cohort cohort, List<String> studentIds) onSubmit;
  final List<Program> programs;
  final List<Profile> trainers;
  final List<Student> allStudents;
  final List<String> initialStudentIds;

  @override
  State<CohortForm> createState() => _CohortFormState();
}

class _CohortFormState extends State<CohortForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _scheduleLabel;
  late final TextEditingController _capacity;
  String? _programId;
  String? _trainerId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isActive = true;
  late Set<String> _selectedStudentIds;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.name ?? '');
    _scheduleLabel = TextEditingController(text: c?.scheduleLabel ?? '');
    _capacity = TextEditingController(text: c?.capacity?.toString() ?? '');
    _programId = c?.programId;
    _trainerId = c?.trainerId;
    _startsAt = c?.startsAt;
    _endsAt = c?.endsAt;
    _isActive = c?.isActive ?? true;
    _selectedStudentIds = widget.initialStudentIds.toSet();
  }

  @override
  void dispose() {
    for (final ctrl in [_name, _scheduleLabel, _capacity]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startsAt : _endsAt) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: isStart ? 'تاريخ البداية' : 'تاريخ النهاية',
    );
    if (picked != null) {
      setState(() => isStart ? _startsAt = picked : _endsAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        Cohort(
          id: widget.initial?.id ?? '',
          name: _name.text.trim(),
          programId: _programId,
          trainerId: _trainerId,
          scheduleLabel: _scheduleLabel.text.trim(),
          startsAt: _startsAt,
          endsAt: _endsAt,
          capacity: int.tryParse(_capacity.text.trim()),
          isActive: _isActive,
          createdAt: widget.initial?.createdAt ?? DateTime.now(),
        ),
        _selectedStudentIds.toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر الحفظ — تأكّد من اتصالك وحاول مجدداً.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(DateTime? d) => d == null ? '—' : '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: NawahSpacing.s5, right: NawahSpacing.s5, top: NawahSpacing.s5,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(editing ? 'تعديل فوج' : 'فوج جديد',
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s5),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الفوج'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل اسماً صحيحاً' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),

              DropdownButtonFormField<String?>(
                initialValue: _programId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'البرنامج (اختياري)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  ...widget.programs.map((p) => DropdownMenuItem(value: p.id, child: Text(p.title))),
                ],
                onChanged: (v) => setState(() => _programId = v),
              ),
              const SizedBox(height: NawahSpacing.s4),

              DropdownButtonFormField<String?>(
                initialValue: _trainerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المدرّب (اختياري)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  ...widget.trainers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.displayName))),
                ],
                onChanged: (v) => setState(() => _trainerId = v),
              ),
              const SizedBox(height: NawahSpacing.s4),

              TextFormField(
                controller: _scheduleLabel,
                decoration: const InputDecoration(labelText: 'الجدول الزمني (مثال: ثلاثاء وخميس ٤–٦م)'),
              ),
              const SizedBox(height: NawahSpacing.s4),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text('من: ${_fmt(_startsAt)}'),
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s3),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text('إلى: ${_fmt(_endsAt)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NawahSpacing.s4),

              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعة القصوى (اختياري)'),
              ),

              if (editing) ...[
                const SizedBox(height: NawahSpacing.s4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('فوج نشط'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],

              if (widget.allStudents.isNotEmpty) ...[
                const SizedBox(height: NawahSpacing.s5),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('الطلاب المسجَّلون بهذا الفوج',
                      style: TextStyle(fontWeight: FontWeight.w700, color: NawahColors.textSoft)),
                ),
                const SizedBox(height: NawahSpacing.s2),
                Wrap(
                  spacing: NawahSpacing.s2,
                  runSpacing: NawahSpacing.s2,
                  children: widget.allStudents.map((s) {
                    final selected = _selectedStudentIds.contains(s.id);
                    return FilterChip(
                      label: Text(s.fullName),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedStudentIds.add(s.id);
                        } else {
                          _selectedStudentIds.remove(s.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: NawahSpacing.s6),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(editing ? 'حفظ التعديلات' : 'إضافة الفوج'),
              ),
              const SizedBox(height: NawahSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }
}
