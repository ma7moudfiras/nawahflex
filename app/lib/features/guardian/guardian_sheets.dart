import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart' show DateFormat;

import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/open_url.dart';
import '../../shared/form_error.dart';
import '../../shared/money.dart';
import '../../shared/section_card.dart';
import '../../shared/sheets.dart';
import '../students/student.dart';
import 'guardian_repository.dart';

const _repo = GuardianRepository();

// ---------------------------------------------------------------------------
// المستحقات — ما يراه ولي الأمر
// ---------------------------------------------------------------------------

class DuesCard extends StatelessWidget {
  const DuesCard({super.key, required this.dues});
  final List<ChildDue> dues;

  @override
  Widget build(BuildContext context) {
    final remaining = dues.fold<num>(0, (a, d) => a + d.remaining);
    final fmt = DateFormat('MMMM y', 'ar');
    return SectionCard(
      title: 'المستحقات',
      icon: Icons.receipt_long_outlined,
      child: dues.isEmpty
          ? const Text('لا مستحقات مسجّلة بعد.', style: TextStyle(color: NawahColors.textMuted, fontSize: 13))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  remaining == 0 ? 'لا مبالغ متبقية — شكراً لكم.' : 'المتبقّي: ${formatMoney(remaining)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: remaining == 0 ? NawahColors.ok : NawahColors.ink,
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                for (final d in dues.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(fmt.format(d.month), style: const TextStyle(color: NawahColors.text))),
                        Text(formatMoney(d.due), style: const TextStyle(color: NawahColors.textMuted, fontSize: 13)),
                        const SizedBox(width: NawahSpacing.s3),
                        SizedBox(
                          width: 92,
                          child: Text(
                            d.settled ? 'مدفوع' : 'متبقٍّ ${formatMoney(d.remaining)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: d.settled ? NawahColors.ok : NawahColors.accentInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// أولياء الأمور — بطاقة الإدارة في ملف الطالب
// ---------------------------------------------------------------------------

class GuardiansCard extends StatefulWidget {
  const GuardiansCard({super.key, required this.student, required this.guardians, required this.onChanged});
  final Student student;
  final List<LinkedGuardian> guardians;
  final VoidCallback onChanged;

  @override
  State<GuardiansCard> createState() => _GuardiansCardState();
}

class _GuardiansCardState extends State<GuardiansCard> {
  String? _busyId;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _invite() async {
    final link = await showAdaptiveSheet<GuardianLink>(
      context,
      builder: (_) => _InviteSheet(student: widget.student),
    );
    if (link == null || !mounted) return;
    widget.onChanged();
    await _showLink(link);
  }

  Future<void> _newLink(LinkedGuardian g) async {
    setState(() => _busyId = g.id);
    try {
      final link = await _repo.loginLink(studentId: widget.student.id, guardianId: g.id);
      if (mounted) await _showLink(link);
    } catch (e, st) {
      if (mounted) _snack(userMessageFor(e, st));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _unlink(LinkedGuardian g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('فكّ ربط ${g.name}؟'),
        content: const Text('لن يرى هذا الطالب في بوابة الأهل بعد الآن. الحساب نفسه يبقى.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('فكّ الربط')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.unlink(studentId: widget.student.id, guardianId: g.id);
      widget.onChanged();
    } catch (e, st) {
      if (mounted) _snack(userMessageFor(e, st));
    }
  }

  Future<void> _showLink(GuardianLink link) => showAdaptiveSheet<void>(
        context,
        builder: (_) => _LinkResultSheet(student: widget.student, link: link),
      );

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'بوابة الأهل',
      icon: Icons.family_restroom_outlined,
      action: TextButton.icon(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_alt, size: 18),
        label: const Text('دعوة'),
      ),
      child: widget.guardians.isEmpty
          ? const Text(
              'لم يُدعَ وليّ أمره بعد. الدعوة تولّد رابطاً ترسله له بواتساب، فيرى تقدّم ابنه وحضوره ومستحقاته.',
              style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.7),
            )
          : Column(
              children: [
                for (final g in widget.guardians)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline, color: NawahColors.ink),
                    title: Text(g.name),
                    subtitle: g.relationship == null ? null : Text(g.relationship!),
                    trailing: _busyId == g.id
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : PopupMenuButton<String>(
                            tooltip: 'خيارات',
                            onSelected: (v) => v == 'link' ? _newLink(g) : _unlink(g),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'link', child: Text('رابط دخول جديد')),
                              PopupMenuItem(value: 'unlink', child: Text('فكّ الربط')),
                            ],
                          ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// لوح الدعوة
// ---------------------------------------------------------------------------

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.student});
  final Student student;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.student.guardianName ?? '');
  late final _email = TextEditingController(text: widget.student.guardianEmail ?? '');
  String _relationship = 'الأب';
  bool _busy = false;
  String? _error;

  static const _relationships = ['الأب', 'الأم', 'غير ذلك'];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await _repo.invite(
        studentId: widget.student.id,
        email: _email.text,
        fullName: _name.text,
        relationship: _relationship,
      );
      if (mounted) Navigator.of(context).pop(link);
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
                  'دعوة وليّ أمر ${widget.student.fullName}',
                  style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
                ),
                const SizedBox(height: NawahSpacing.s1),
                const Text(
                  'يُنشأ له حساب ويُربط بالطالب، ويظهر رابط دخول ترسله له بواتساب.',
                  style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: NawahSpacing.s4),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم ولي الأمر'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب الاسم' : null,
                ),
                const SizedBox(height: NawahSpacing.s3),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', helperText: 'يدخل به لاحقاً مع كلمة مرور يضبطها بنفسه.'),
                  validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : 'بريد غير صالح',
                ),
                const SizedBox(height: NawahSpacing.s3),
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  decoration: const InputDecoration(labelText: 'الصلة'),
                  items: [for (final r in _relationships) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: _busy ? null : (v) => setState(() => _relationship = v ?? _relationship),
                ),
                const SizedBox(height: NawahSpacing.s4),
                FormErrorBanner(message: _error),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('إنشاء رابط الدعوة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرابط الناتج — إرسال بواتساب أو نسخ
// ---------------------------------------------------------------------------

class _LinkResultSheet extends StatelessWidget {
  const _LinkResultSheet({required this.student, required this.link});
  final Student student;
  final GuardianLink link;

  String get _message =>
      'مرحباً، هذا رابط دخولك إلى بوابة أهالي أكاديمية نواة لمتابعة ${student.fullName}:\n${link.link}\n'
      'الرابط يُستعمل مرة واحدة. بعد الدخول اضبط كلمة مرور لتدخل لاحقاً ببريدك.';

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
            const Icon(Icons.mark_email_read_outlined, size: 40, color: NawahColors.ok),
            const SizedBox(height: NawahSpacing.s3),
            Text(
              link.existing ? 'رابط دخول جاهز' : 'تمّت الدعوة',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
            ),
            const SizedBox(height: NawahSpacing.s2),
            const Text(
              'أرسل الرابط لولي الأمر الآن: يُستعمل مرة واحدة وصلاحيته محدودة (ساعة عادةً). إن انتهى، أنشئ رابطاً جديداً من بطاقة «بوابة الأهل».',
              textAlign: TextAlign.center,
              style: TextStyle(color: NawahColors.textSoft, height: 1.7, fontSize: 13),
            ),
            const SizedBox(height: NawahSpacing.s4),
            if (wa.isNotEmpty)
              FilledButton.icon(
                onPressed: () => openExternal('$wa?text=${Uri.encodeComponent(_message)}'),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('إرسال بواتساب'),
              ),
            const SizedBox(height: NawahSpacing.s2),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _message));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخت الرسالة مع الرابط.')));
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('نسخ الرسالة'),
            ),
          ],
        ),
      ),
    );
  }
}
