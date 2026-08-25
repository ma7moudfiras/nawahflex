import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import 'auth_service.dart';

/// شاشة الدخول — بطاقة موسّطة على المكتب، صفحة كاملة على الجوّال.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NawahColors.ink,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NawahSpacing.s5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              color: NawahColors.card,
              child: Padding(
                padding: EdgeInsets.all(adaptive(context, mobile: 24.0, tablet: 32.0)),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('لوحة إدارة نواة فليكس',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: NawahFonts.display,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: NawahColors.ink,
                          )),
                      const SizedBox(height: NawahSpacing.s2),
                      const Text('سجّل الدخول بحسابك للمتابعة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: NawahColors.textSoft, fontSize: 14)),
                      const SizedBox(height: NawahSpacing.s6),

                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'أدخل البريد الإلكتروني';
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
                            return 'صيغة البريد غير صحيحة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: NawahSpacing.s4),

                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textDirection: TextDirection.ltr,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            tooltip: _obscure ? 'إظهار' : 'إخفاء',
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'أدخل كلمة المرور' : null,
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: NawahSpacing.s4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(NawahRadius.sm),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                        ),
                      ],

                      const SizedBox(height: NawahSpacing.s5),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('دخول'),
                      ),
                      const SizedBox(height: NawahSpacing.s4),
                      const Text(
                        'الحسابات تُنشأ من إدارة الأكاديمية. إن لم يكن لديك حساب، تواصل مع المدير.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NawahColors.textMuted, fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
