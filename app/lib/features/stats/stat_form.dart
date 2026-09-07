import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import 'stat_item.dart';

/// نموذج إضافة/تعديل بطاقة إحصاء.
class StatForm extends StatefulWidget {
  const StatForm({super.key, this.initial, required this.onSubmit});

  final StatItem? initial;
  final Future<void> Function(StatItem stat) onSubmit;

  @override
  State<StatForm> createState() => _StatFormState();
}

class _StatFormState extends State<StatForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _value;
  late final TextEditingController _suffix;
  late final TextEditingController _icon;
  late final TextEditingController _sortOrder;
  bool _isPublished = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _label = TextEditingController(text: s?.label ?? '');
    _value = TextEditingController(text: s?.value.toString() ?? '');
    _suffix = TextEditingController(text: s?.suffix ?? '');
    _icon = TextEditingController(text: s?.icon ?? '');
    _sortOrder = TextEditingController(text: s?.sortOrder.toString() ?? '0');
    _isPublished = s?.isPublished ?? true;
  }

  @override
  void dispose() {
    for (final c in [_label, _value, _suffix, _icon, _sortOrder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(StatItem(
        id: widget.initial?.id ?? '',
        label: _label.text.trim(),
        value: int.parse(_value.text.trim()),
        suffix: _suffix.text.trim(),
        icon: _icon.text.trim(),
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
        isPublished: _isPublished,
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
              Text(editing ? 'تعديل بطاقة إحصاء' : 'بطاقة إحصاء جديدة',
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s5),

              TextFormField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'التسمية (مثال: طالب وطالبة)'),
                validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل تسمية صحيحة' : null,
              ),
              const SizedBox(height: NawahSpacing.s4),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الرقم'),
                      validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'رقم صحيح فقط' : null,
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s3),
                  Expanded(
                    child: TextFormField(
                      controller: _suffix,
                      decoration: const InputDecoration(labelText: 'لاحقة (مثال: +)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NawahSpacing.s4),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _icon,
                      decoration: const InputDecoration(labelText: 'أيقونة (رمز تعبيري، اختياري)'),
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s3),
                  Expanded(
                    child: TextFormField(
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ترتيب الظهور'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NawahSpacing.s4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تظهر بالموقع'),
                value: _isPublished,
                onChanged: (v) => setState(() => _isPublished = v),
              ),

              const SizedBox(height: NawahSpacing.s6),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(editing ? 'حفظ التعديلات' : 'إضافة البطاقة'),
              ),
              const SizedBox(height: NawahSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }
}
