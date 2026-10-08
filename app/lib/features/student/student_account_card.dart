import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/open_url.dart';
import '../../shared/form_error.dart';
import '../../shared/section_card.dart';
import '../../shared/sheets.dart';
import '../students/student.dart';
import 'student_account_repository.dart';

const _repo = StudentAccountRepository();

/// «حساب الطالب» في ملفه — للإدارة: إنشاء حساب باسم مستخدم، أو كلمة مرور
/// جديدة. الحساب يُرسل لولي الأمر بواتساب أو يُنسخ؛ كلمة المرور لا تُخزَّن.
class StudentAccountCard extends StatefulWidget {
  const StudentAccountCard({super.key, required this.student, required this.username});
  final Student student;

  /// اسم المستخدم الحالي، أو null إن لم يُنشأ حساب.
  final String? username;

  @override
  State<StudentAccountCard> createState() => _StudentAccountCardState();
}

class _StudentAccountCardState extends State<StudentAccountCard> {
  late String? _username = widget.username;
  bool _busy = false;

  Future<void> _create() async {
    final creds = await showAdaptiveSheet<StudentCredentials>(
      context,
      builder: (_) => _CreateSheet(student: widget.student),
    );
    if (creds == null || !mounted) return;
    setState(() => _username = creds.username);
    await _show(creds);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كلمة مرور جديدة؟'),
        content: const Text('تتوقّف كلمة المرور الحالية فوراً، وتظهر كلمة جديدة ترسلها للطالب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final creds = await _repo.resetPassword(widget.student.id);
      if (mounted) await _show(creds);
    } catch (e, st) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessageFor(e, st))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _show(StudentCredentials c) => showAdaptiveSheet<void>(
        context,
        builder: (_) => _CredentialsSheet(student: widget.student, creds: c),
      );

  @override
  Widget build(BuildContext context) {
    final u = _username;
    return SectionCard(
      title: 'حساب الطالب',
      icon: Icons.person_pin_outlined,
      action: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : u == null
              ? TextButton.icon(onPressed: _create, icon: const Icon(Icons.add, size: 18), label: const Text('إنشاء'))
              : TextButton.icon(onPressed: _reset, icon: const Icon(Icons.key_outlined, size: 18), label: const Text('كلمة مرور جديدة')),
      child: u == null
          ? const Text(
              'للطلاب من ١٠ سنوات: يدخل باسم مستخدم وكلمة مرور ويرى إطاره وشاراته ومهاراته — بلا مالية ولا ملاحظات.',
              style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.7),
            )
          : Row(
              children: [
                const Text('اسم المستخدم: ', style: TextStyle(color: NawahColors.textMuted, fontSize: 13)),
                Text(u, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink)),
              ],
            ),
    );
  }
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({required this.student});
  final Student student;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await _repo.create(widget.student.id, _username.text);
      if (mounted) Navigator.of(context).pop(c);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NawahSpacing.s5),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'حساب لـ ${widget.student.fullName}',
                  style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
                ),
                const SizedBox(height: NawahSpacing.s1),
                const Text(
                  'اختر اسم مستخدم بالإنجليزية يسهل على الطالب تذكّره. كلمة المرور تُولَّد تلقائياً.',
                  style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: NawahSpacing.s4),
                TextFormField(
                  controller: _username,
                  autofocus: true,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم', hintText: 'مثال: diyar.a'),
                  validator: (v) => RegExp(r'^[a-z0-9._]{3,20}$').hasMatch((v ?? '').trim().toLowerCase())
                      ? null
                      : '٣–٢٠ حرفاً إنجليزياً صغيراً أو أرقاماً أو نقطة',
                ),
                const SizedBox(height: NawahSpacing.s4),
                FormErrorBanner(message: _error),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('إنشاء الحساب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CredentialsSheet extends StatelessWidget {
  const _CredentialsSheet({required this.student, required this.creds});
  final Student student;
  final StudentCredentials creds;

  String get _message =>
      'حساب ${student.fullName} في بوابة أكاديمية نواة:\n'
      'الرابط: https://www.nawahflex.org/app/\n'
      'اسم المستخدم: ${creds.username}\n'
      'كلمة المرور: ${creds.password}';

  @override
  Widget build(BuildContext context) {
    final wa = student.whatsappUrl;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(NawahSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'بيانات الدخول',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
            ),
            const SizedBox(height: NawahSpacing.s3),
            Container(
              padding: const EdgeInsets.all(NawahSpacing.s4),
              decoration: BoxDecoration(color: NawahColors.paper, borderRadius: BorderRadius.circular(NawahRadius.md)),
              child: Column(
                children: [
                  _Line('اسم المستخدم', creds.username),
                  const SizedBox(height: NawahSpacing.s2),
                  _Line('كلمة المرور', creds.password),
                ],
              ),
            ),
            const SizedBox(height: NawahSpacing.s3),
            const Text(
              'تظهر كلمة المرور الآن فقط ولا تُحفظ. أرسلها الآن؛ وإن ضاعت أنشئ كلمة جديدة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: NawahColors.textSoft, fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: NawahSpacing.s4),
            if (wa.isNotEmpty)
              FilledButton.icon(
                onPressed: () => openExternal('$wa?text=${Uri.encodeComponent(_message)}'),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('إرسال لولي الأمر بواتساب'),
              ),
            const SizedBox(height: NawahSpacing.s2),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _message));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخت بيانات الدخول.')));
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('نسخ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label, style: const TextStyle(color: NawahColors.textMuted)),
          const Spacer(),
          SelectableText(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: NawahColors.ink, letterSpacing: 1),
          ),
        ],
      );
}
