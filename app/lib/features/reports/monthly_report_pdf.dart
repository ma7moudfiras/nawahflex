import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../brand/pdf_brand.dart';
import '../../shared/months.dart';
import '../attendance/attendance_status.dart';
import '../progress/progress_models.dart';
import 'monthly_report.dart';

/// تقرير الشهر PDF — A4 عمودي، صفحات حسب الطول. يُقرأ على الجوّال ويُطبع.
Future<Uint8List> buildMonthlyReportPdf({
  required MonthlyReport report,
  required PdfFonts fonts,
  DateTime? generatedAt,
}) async {
  final r = report;
  final monthLabel = arabicMonthLabel(r.month);
  final doc = pw.Document(
    theme: fonts.theme,
    title: 'تقرير $monthLabel — ${r.studentName}',
    author: 'أكاديمية نواة',
    creator: 'بوابة أكاديمية نواة',
  );

  pw.TextStyle display(double size, {PdfColor? color, bool extra = false}) =>
      pw.TextStyle(font: extra ? fonts.displayBold : fonts.display, fontSize: size, color: color ?? PdfPalette.ink);
  pw.TextStyle body(double size, {PdfColor? color, bool bold = false}) =>
      pw.TextStyle(font: bold ? fonts.bodyBold : fonts.body, fontSize: size, color: color ?? PdfPalette.textSoft, lineSpacing: 3);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
        child: pw.Row(
          children: [
            pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: PdfPalette.accent, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 6),
            pw.Text(text, style: display(13)),
          ],
        ),
      );

  pw.Widget empty(String text) => pw.Text(text, style: body(10, color: PdfPalette.textMuted));

  pw.Widget stat(String value, String label) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: pw.BoxDecoration(color: PdfPalette.inkTint, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(
            children: [
              pw.Text(value, style: display(18, extra: true)),
              pw.SizedBox(height: 2),
              pw.Text(label, style: body(9), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      );

  // صفّ جدول: النص في البداية (يمين) والقيمة في النهاية.
  pw.Widget row(String start, pw.Widget end, {bool shaded = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        color: shaded ? PdfPalette.paper : null,
        child: pw.Row(children: [pw.Expanded(child: pw.Text(start, style: body(10, color: PdfPalette.ink))), end]),
      );

  PdfColor statusColor(String s) => switch (s) {
        AttendanceStatus.present => PdfPalette.ok,
        AttendanceStatus.absent => PdfPalette.err,
        _ => PdfPalette.textSoft,
      };

  // مقياس المهارة: أربعة مربّعات، المنال منها كحلي.
  pw.Widget meter(int? level) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var i = 1; i <= SkillLevel.max; i++) ...[
            if (i > 1) pw.SizedBox(width: 3),
            pw.Container(
              width: 14,
              height: 6,
              decoration: pw.BoxDecoration(
                color: (level ?? 0) >= i ? PdfPalette.ink : PdfPalette.inkTint,
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      );

  final rate = r.attendanceRate;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      textDirection: pw.TextDirection.rtl,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text('${r.studentName} — تقرير $monthLabel', style: body(9, color: PdfPalette.textMuted)),
            ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfPalette.border, width: 0.6))),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'أكاديمية نواة · nawahflex.org${generatedAt == null ? '' : ' · أُعدّ في ${pdfDate(generatedAt)}'}',
                style: body(8, color: PdfPalette.textMuted),
              ),
            ),
            pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: body(8, color: PdfPalette.textMuted)),
          ],
        ),
      ),
      build: (context) => [
        // ---- الرأس ----
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SvgImage(svg: nawahLogoSvg(), height: 44),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('أكاديمية نواة', style: display(15, extra: true)),
                  pw.Text('التقرير الشهري لولي الأمر', style: body(10, color: PdfPalette.textMuted)),
                ],
              ),
            ),
            pw.Text(monthLabel, style: display(16, color: PdfPalette.accentInk, extra: true)),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 2, color: PdfPalette.ink),
        pw.SizedBox(height: 14),

        // ---- الطالب ومستواه ----
        pw.Text(r.studentName, style: display(22, extra: true)),
        pw.SizedBox(height: 4),
        pw.Text(
          'المستوى ${r.level} · ${r.levelTitle} — ${r.points} نقطة'
          '${r.pointsToNext == null ? ' — أعلى مستوى' : ' — بقي ${r.pointsToNext} نقطة للمستوى التالي'}',
          style: body(11, color: PdfPalette.ink),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            stat('${r.attended} من ${r.attendance.length}', 'حصص حضرها'),
            stat(rate == null ? '—' : '$rate%', 'نسبة الالتزام'),
            stat('${r.badges.length}', 'شارات جديدة'),
            stat('${r.projects.length}', 'مشاريع جديدة'),
          ],
        ),

        // ---- الحضور ----
        heading('الحضور'),
        if (r.attendance.isEmpty)
          empty('لا حصص مسجّلة هذا الشهر.')
        else
          for (var i = 0; i < r.attendance.length; i++)
            row(
              pdfDate(r.attendance[i].date),
              pw.Text(
                AttendanceStatus.labels[r.attendance[i].status] ?? r.attendance[i].status,
                style: body(10, color: statusColor(r.attendance[i].status), bold: true),
              ),
              shaded: i.isOdd,
            ),

        // ---- الشارات ----
        heading('الشارات التي نالها'),
        if (r.badges.isEmpty)
          empty('لا شارات جديدة هذا الشهر.')
        else
          for (var i = 0; i < r.badges.length; i++)
            row(r.badges[i].title, pw.Text(pdfDate(r.badges[i].at), style: body(9)), shaded: i.isOdd),

        // ---- المشاريع ----
        heading('المشاريع'),
        if (r.projects.isEmpty)
          empty('لا مشاريع جديدة هذا الشهر.')
        else
          for (var i = 0; i < r.projects.length; i++)
            row(
              r.projects[i].title,
              pw.Text(
                r.projects[i].rating == null ? pdfDate(r.projects[i].at) : 'التقييم ${r.projects[i].rating} من 5',
                style: body(9),
              ),
              shaded: i.isOdd,
            ),

        // ---- المهارات ----
        heading('المهارات'),
        if (r.skills.isEmpty)
          empty('لم تُحدَّد مهارات البرنامج بعد.')
        else
          for (var i = 0; i < r.skills.length; i++)
            row(
              r.skills[i].title,
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.SizedBox(
                    width: 52,
                    child: pw.Text(
                      r.skills[i].level == null ? '—' : SkillLevel.label(r.skills[i].level!),
                      style: body(9, color: PdfPalette.ink),
                    ),
                  ),
                  meter(r.skills[i].level),
                ],
              ),
              shaded: i.isOdd,
            ),

        // ---- ملاحظات المدرّب ----
        heading('ملاحظات المدرّب'),
        if (r.notes.isEmpty)
          empty('لا ملاحظات هذا الشهر.')
        else
          for (final n in r.notes)
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfPalette.border, width: 0.6),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(n.body, style: body(10, color: PdfPalette.ink)),
                  pw.SizedBox(height: 3),
                  pw.Text(pdfDate(n.at), style: body(8, color: PdfPalette.textMuted)),
                ],
              ),
            ),
      ],
    ),
  );
  return doc.save();
}
