import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import 'student.dart';

/// نموذج إضافة/تعديل طالب — يُفتح كـ bottom sheet على الجوّال وحوار على الأوسع،
/// القرار يتّخذه المستدعي عبر showModalBottomSheet أو showDialog حسب الحجم.
class StudentForm extends StatefulWidget {
  const StudentForm({super.key, this.initial, required this.onSubmit});

  final Student? initial;
  final Future<void> Function(Student student) onSubmit;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianPhone;
  late final TextEditingController _guardianEmail;
  late final TextEditingController _notes;
  DateTime? _birthDate;
  String? _gender;
  bool _busy = false;

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
  }

  @override
  void dispose() {
    for (final c in [_name, _guardianName, _guardianPhone, _guardianEmail, _notes]) {
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
      await widget.onSubmit(Student(
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
      ));
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
              Text(editing ? 'تعديل بيانات الطالب' : 'طالب جديد',
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s5),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الطالب الكامل'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل اسماً صحيحاً' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickBirthDate,
                      icon: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(_birthDate == null
                          ? 'تاريخ الميلاد'
                          : '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}'),
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
                child: Text('ولي الأمر',
                    style: TextStyle(fontWeight: FontWeight.w700, color: NawahColors.textSoft)),
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
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)'),
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),

              const SizedBox(height: NawahSpacing.s6),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
