import 'package:flutter/material.dart';

import '../../brand/pdf_brand.dart';
import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/save_file.dart';
import '../../shared/form_error.dart';
import '../../shared/months.dart';
import '../../shared/sheets.dart';
import 'monthly_report.dart';
import 'monthly_report_pdf.dart';

/// لوح «تقرير الشهر»: اختيار شهر من آخر ستة، ثم توليد PDF وتحميله.
/// [build] يجمع بيانات الشهر (مصدر الحضور يختلف بين الإدارة وولي الأمر).
Future<void> showMonthlyReportSheet(
  BuildContext context, {
  required String studentName,
  required Future<MonthlyReport> Function(DateTime month) build,
}) =>
    showAdaptiveSheet<void>(
      context,
      builder: (_) => _ReportSheet(studentName: studentName, build: build),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.studentName, required this.build});
  final String studentName;
  final Future<MonthlyReport> Function(DateTime month) build;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _months = MonthlyReport.recentMonths(DateTime.now());
  late DateTime _month = _months.first;
  bool _busy = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await widget.build(_month);
      final bytes = await buildMonthlyReportPdf(report: report, fonts: await PdfFonts.load(), generatedAt: DateTime.now());
      final mm = _month.month.toString().padLeft(2, '0');
      // اسم لاتيني — انظر Certificate.fileName.
      await saveFile(bytes, filename: 'nawah-report-${_month.year}-$mm.pdf', mimeType: 'application/pdf');
      if (mounted) Navigator.of(context).pop();
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NawahSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تقرير الشهر — ${widget.studentName}',
              style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
            ),
            const SizedBox(height: NawahSpacing.s1),
            const Text(
              'الحضور، والشارات والمشاريع الجديدة، والمهارات، وملاحظات المدرّب للأهل — ملف PDF يُطبع أو يُرسل.',
              style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: NawahSpacing.s4),
            Wrap(
              spacing: NawahSpacing.s2,
              runSpacing: NawahSpacing.s2,
              children: [
                for (final m in _months)
                  ChoiceChip(
                    label: Text(arabicMonthLabel(m)),
                    selected: m == _month,
                    onSelected: _busy ? null : (_) => setState(() => _month = m),
                  ),
              ],
            ),
            const SizedBox(height: NawahSpacing.s5),
            FormErrorBanner(message: _error),
            FilledButton.icon(
              onPressed: _busy ? null : _download,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined, size: 18),
              label: const Text('تحميل التقرير'),
            ),
          ],
        ),
      ),
    );
  }
}
