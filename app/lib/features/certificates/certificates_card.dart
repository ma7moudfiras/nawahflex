import 'package:flutter/material.dart';

import '../../brand/pdf_brand.dart';
import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/save_file.dart';
import '../../shared/form_error.dart';
import '../../shared/section_card.dart';
import '../../shared/sheets.dart';
import 'certificate.dart';
import 'certificate_pdf.dart';
import 'certificates_repository.dart';

const _repo = CertificatesRepository();

/// يولّد الشهادة PDF على الجهاز ويحفظها — لا ملفات مخزّنة على الخادم:
/// الشهادة الحقيقية هي صفّ القاعدة، والملف نسخة منها تُولَّد كلما طُلبت.
Future<void> downloadCertificate(Certificate c, String studentName) async {
  final bytes = await buildCertificatePdf(certificate: c, studentName: studentName, fonts: await PdfFonts.load());
  await saveFile(bytes, filename: c.fileName, mimeType: 'application/pdf');
}

class CertificatesCard extends StatefulWidget {
  const CertificatesCard({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.certificates,
    required this.onChanged,
    this.canIssue = false,
    this.programs = const [],
    this.level,
    this.title = 'الشهادات',
  });

  final String studentId;
  final String studentName;
  final List<Certificate> certificates;
  final VoidCallback onChanged;

  /// الإدارة وحدها تصدر وتلغي (والسياسة تفرض ذلك في القاعدة).
  final bool canIssue;

  /// برامج الطالب (المعرّف، العنوان) — لاقتراح عنوان «إتمام برنامج».
  final List<({String id, String title})> programs;

  /// المستوى الحالي (الرقم، الاسم) — لاقتراح «بلوغ مستوى».
  final ({int level, String title})? level;
  final String title;

  @override
  State<CertificatesCard> createState() => _CertificatesCardState();
}

class _CertificatesCardState extends State<CertificatesCard> {
  String? _busyId;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _download(Certificate c) async {
    setState(() => _busyId = c.id);
    try {
      await downloadCertificate(c, widget.studentName);
    } catch (e, st) {
      if (mounted) _snack(userMessageFor(e, st));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _issue() async {
    final c = await showAdaptiveSheet<Certificate>(
      context,
      builder: (_) => _IssueSheet(
        studentId: widget.studentId,
        studentName: widget.studentName,
        programs: widget.programs,
        level: widget.level,
      ),
    );
    if (c == null || !mounted) return;
    widget.onChanged();
    _snack('صدرت الشهادة ${c.code}');
  }

  Future<void> _revoke(Certificate c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الشهادة؟'),
        content: Text(
          '«${c.title}» برقم ${c.code}.\nستظهر «ملغاة» لكل من يتحقّق منها، ولا يمكن التراجع.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NawahColors.err),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الشهادة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.revoke(c.id);
      widget.onChanged();
    } catch (e, st) {
      if (mounted) _snack(userMessageFor(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.certificates;
    return SectionCard(
      title: widget.title,
      icon: Icons.workspace_premium_outlined,
      action: widget.canIssue
          ? TextButton.icon(onPressed: _issue, icon: const Icon(Icons.add, size: 18), label: const Text('إصدار'))
          : null,
      child: list.isEmpty
          ? Text(
              widget.canIssue
                  ? 'لا شهادات بعد. تصدرها عند إتمام برنامج أو بلوغ مستوى، وفيها رمز يتحقّق به أيّ أحد من صحتها.'
                  : 'لا شهادات بعد.',
              style: const TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.7),
            )
          : Column(
              children: [
                for (final c in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      c.isRevoked ? Icons.block : Icons.workspace_premium_outlined,
                      color: c.isRevoked ? NawahColors.textMuted : NawahColors.ink,
                    ),
                    title: Text(
                      c.title,
                      style: TextStyle(
                        color: c.isRevoked ? NawahColors.textMuted : NawahColors.text,
                        decoration: c.isRevoked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${pdfDate(c.issuedAt)} · '),
                        TextSpan(text: c.code, style: const TextStyle(color: NawahColors.accentInk, fontWeight: FontWeight.w700)),
                        if (c.isRevoked) const TextSpan(text: ' · ملغاة', style: TextStyle(color: NawahColors.err)),
                      ]),
                      style: const TextStyle(fontSize: 12, color: NawahColors.textMuted),
                    ),
                    trailing: _busyId == c.id
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!c.isRevoked)
                                IconButton(
                                  tooltip: 'تحميل PDF',
                                  onPressed: () => _download(c),
                                  icon: const Icon(Icons.download_outlined),
                                ),
                              if (widget.canIssue && !c.isRevoked)
                                PopupMenuButton<String>(
                                  tooltip: 'خيارات',
                                  onSelected: (_) => _revoke(c),
                                  itemBuilder: (_) => const [PopupMenuItem(value: 'revoke', child: Text('إلغاء الشهادة'))],
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
// لوح الإصدار
// ---------------------------------------------------------------------------

class _IssueSheet extends StatefulWidget {
  const _IssueSheet({required this.studentId, required this.studentName, required this.programs, this.level});
  final String studentId;
  final String studentName;
  final List<({String id, String title})> programs;
  final ({int level, String title})? level;

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<_IssueSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late String _kind = widget.programs.isNotEmpty ? 'program' : 'level';
  late String? _programId = widget.programs.firstOrNull?.id;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// عنوان مقترح حسب النوع — يعدّله المدير كما يشاء قبل الإصدار.
  void _suggest() {
    final program = widget.programs.where((p) => p.id == _programId).firstOrNull;
    final l = widget.level;
    _title.text = switch (_kind) {
      'program' when program != null => 'إتمام برنامج ${program.title}',
      'level' when l != null => 'بلوغ المستوى ${l.level} «${l.title}»',
      _ => '',
    };
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await _repo.issue(
        studentId: widget.studentId,
        kind: _kind,
        title: _title.text,
        programId: _kind == 'program' ? _programId : null,
        level: _kind == 'level' ? widget.level?.level : null,
      );
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
                  'شهادة لـ ${widget.studentName}',
                  style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
                ),
                const SizedBox(height: NawahSpacing.s1),
                const Text(
                  'يُولَّد لها رقم فريد ورمز QR يفتح صفحة التحقّق على موقع الأكاديمية.',
                  style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: NawahSpacing.s4),
                SegmentedButton<String>(
                  segments: [
                    for (final e in Certificate.kinds.entries) ButtonSegment(value: e.key, label: Text(e.value)),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _kind = s.first;
                    _suggest();
                  }),
                ),
                if (_kind == 'program' && widget.programs.length > 1) ...[
                  const SizedBox(height: NawahSpacing.s3),
                  DropdownButtonFormField<String>(
                    initialValue: _programId,
                    decoration: const InputDecoration(labelText: 'البرنامج'),
                    items: [for (final p in widget.programs) DropdownMenuItem(value: p.id, child: Text(p.title))],
                    onChanged: (v) => setState(() {
                      _programId = v;
                      _suggest();
                    }),
                  ),
                ],
                if (_kind == 'program' && widget.programs.isEmpty) ...[
                  const SizedBox(height: NawahSpacing.s2),
                  const Text('الطالب غير مسجّل في أي برنامج.', style: TextStyle(color: NawahColors.accentInk, fontSize: 12)),
                ],
                const SizedBox(height: NawahSpacing.s3),
                TextFormField(
                  controller: _title,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'نص الشهادة', helperText: 'يُطبع تحت اسم الطالب كما تكتبه.'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب نص الشهادة' : null,
                ),
                const SizedBox(height: NawahSpacing.s4),
                FormErrorBanner(message: _error),
                FilledButton(
                  onPressed: _busy || (_kind == 'program' && _programId == null) ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('إصدار الشهادة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
