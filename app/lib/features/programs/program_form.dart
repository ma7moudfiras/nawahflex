import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import 'program.dart';

/// نموذج إضافة/تعديل برنامج — Dialog على الشاشات الواسعة، bottom sheet
/// على الجوّال، بنفس نمط StudentForm.
class ProgramForm extends StatefulWidget {
  const ProgramForm({super.key, this.initial, required this.onSubmit});

  final Program? initial;
  final Future<void> Function(Program program) onSubmit;

  @override
  State<ProgramForm> createState() => _ProgramFormState();
}

class _ProgramFormState extends State<ProgramForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _ageMin;
  late final TextEditingController _ageMax;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _title = TextEditingController(text: p?.title ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _ageMin = TextEditingController(text: p?.ageMin?.toString() ?? '');
    _ageMax = TextEditingController(text: p?.ageMax?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _ageMin, _ageMax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(Program(
        id: widget.initial?.id ?? '',
        title: _title.text.trim(),
        description: _description.text.trim(),
        ageMin: int.tryParse(_ageMin.text.trim()),
        ageMax: int.tryParse(_ageMax.text.trim()),
        isPublished: widget.initial?.isPublished ?? true,
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
              Text(editing ? 'تعديل برنامج' : 'برنامج جديد',
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s5),

              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'اسم البرنامج'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل اسماً صحيحاً' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف مختصر'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل وصفاً صحيحاً' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),

              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('الفئة العمرية (اختياري)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: NawahColors.textSoft)),
              ),
              const SizedBox(height: NawahSpacing.s2),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageMin,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'من'),
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s3),
                  Expanded(
                    child: TextFormField(
                      controller: _ageMax,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'إلى'),
                    ),
                  ),
                ],
              ),
              Builder(builder: (context) {
                final min = int.tryParse(_ageMin.text.trim());
                final max = int.tryParse(_ageMax.text.trim());
                if (min != null && max != null && max < min) {
                  return const Padding(
                    padding: EdgeInsets.only(top: NawahSpacing.s2),
                    child: Text('الحد الأعلى يجب أن يكون أكبر من أو يساوي الحد الأدنى',
                        style: TextStyle(color: NawahColors.rose, fontSize: 12)),
                  );
                }
                return const SizedBox.shrink();
              }),

              const SizedBox(height: NawahSpacing.s6),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(editing ? 'حفظ التعديلات' : 'إضافة البرنامج'),
              ),
              const SizedBox(height: NawahSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }
}
