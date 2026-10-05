import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, UserAttributes;

import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../shared/form_error.dart';
import '../../shared/sheets.dart';

/// تغيير كلمة المرور من داخل اللوحة.
///
/// لماذا هنا لا عبر «نسيت كلمة المرور»؟ خطة Supabase المجانية لا ترسل بريد
/// الاستعادة إلا لأعضاء فريق المشروع — المدرّب أو المدير الجديد لن يصله
/// شيء. فالمسجَّل دخوله يغيّر كلمته بنفسه من هنا، دون أي بريد.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showAdaptiveSheet<void>(
    context,
    maxWidth: 420,
    builder: (_) => const _ChangePasswordForm(),
  );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static const _minLength = 8;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور.')),
      );
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      setState(() => _error = m.contains('different from the old')
          ? 'كلمة المرور الجديدة مطابقة للحالية — اختر كلمة أخرى.'
          : m.contains('weak') || m.contains('at least')
              ? 'كلمة المرور ضعيفة. استعمل $_minLength أحرف على الأقل مع أرقام.'
              : userMessageFor(e));
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NawahSpacing.s5,
        NawahSpacing.s5,
        NawahSpacing.s5,
        NawahSpacing.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تغيير كلمة المرور',
                style: TextStyle(
                  fontFamily: NawahFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: NawahColors.ink,
                ),
              ),
              const SizedBox(height: NawahSpacing.s5),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  helperText: '$_minLength أحرف على الأقل',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'إظهار' : 'إخفاء',
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').length < _minLength
                    ? 'كلمة المرور أقصر من $_minLength أحرف'
                    : null,
              ),
              const SizedBox(height: NawahSpacing.s4),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                validator: (v) =>
                    v != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: NawahSpacing.s5),
              FormErrorBanner(message: _error),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حفظ كلمة المرور'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
