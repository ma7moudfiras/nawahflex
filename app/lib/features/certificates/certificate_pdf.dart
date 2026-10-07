import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../brand/pdf_brand.dart';
import 'certificate.dart';

/// الشهادة PDF — A4 أفقي، إطار كحلي بزوايا الشعار المستديرة، ورمز QR إلى
/// صفحة التحقّق العلنية. لا تدرّجات ولا زخرفة: الهوية هي الإطار والنقاط.
Future<Uint8List> buildCertificatePdf({
  required Certificate certificate,
  required String studentName,
  required PdfFonts fonts,
}) async {
  final doc = pw.Document(
    theme: fonts.theme,
    title: '${certificate.title} — $studentName',
    author: 'أكاديمية نواة',
    creator: 'بوابة أكاديمية نواة',
  );

  pw.TextStyle display(double size, {PdfColor? color, bool extra = false}) =>
      pw.TextStyle(font: extra ? fonts.displayBold : fonts.display, fontSize: size, color: color ?? PdfPalette.ink);
  pw.TextStyle body(double size, {PdfColor? color, bool bold = false}) =>
      pw.TextStyle(font: bold ? fonts.bodyBold : fonts.body, fontSize: size, color: color ?? PdfPalette.textSoft);

  final kindLabel = switch (certificate.kind) {
    'program' => 'شهادة إتمام برنامج',
    'level' => 'شهادة بلوغ مستوى',
    _ => 'شهادة',
  };

  // ثلاث نقاط قرميدية — نقاط الشعار، فاصلاً بين الأقسام.
  pw.Widget dots() => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) pw.SizedBox(width: 6),
            pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: PdfPalette.accent, shape: pw.BoxShape.circle)),
          ],
        ],
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      textDirection: pw.TextDirection.rtl,
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfPalette.ink, width: 4),
          borderRadius: pw.BorderRadius.circular(28),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfPalette.border, width: 0.8),
            borderRadius: pw.BorderRadius.circular(20),
          ),
          padding: const pw.EdgeInsets.fromLTRB(44, 30, 44, 26),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SvgImage(svg: nawahLogoSvg(), height: 64),
              pw.SizedBox(height: 8),
              pw.Text('أكاديمية نواة', style: display(20, extra: true)),
              pw.Text('كل اختراع يبدأ بنواة', style: body(10, color: PdfPalette.textMuted)),
              pw.Spacer(),
              pw.Text(kindLabel, style: display(30, extra: true)),
              pw.SizedBox(height: 10),
              dots(),
              pw.SizedBox(height: 16),
              pw.Text('تُمنح هذه الشهادة إلى', style: body(13)),
              pw.SizedBox(height: 8),
              pw.Text(studentName, style: display(36, extra: true), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 12),
              pw.Container(
                constraints: const pw.BoxConstraints(maxWidth: 560),
                child: pw.Text(
                  certificate.title,
                  style: body(16, color: PdfPalette.ink, bold: true),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Spacer(),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // التاريخ (يمين الصفحة — أول الصف في RTL)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('تاريخ الإصدار', style: body(9, color: PdfPalette.textMuted)),
                        pw.SizedBox(height: 2),
                        pw.Text(pdfDate(certificate.issuedAt), style: body(12, color: PdfPalette.ink, bold: true)),
                      ],
                    ),
                  ),
                  // التوقيع
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(width: 150, height: 0.8, color: PdfPalette.ink),
                        pw.SizedBox(height: 4),
                        pw.Text('إدارة أكاديمية نواة', style: body(10, color: PdfPalette.ink)),
                      ],
                    ),
                  ),
                  // رمز التحقّق (يسار الصفحة)
                  pw.Expanded(
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('رقم الشهادة', style: body(9, color: PdfPalette.textMuted)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              certificate.code,
                              textDirection: pw.TextDirection.ltr,
                              style: display(12, color: PdfPalette.accentInk).copyWith(letterSpacing: 1),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text('تحقّق: nawahflex.org/verify', style: body(8, color: PdfPalette.textMuted)),
                          ],
                        ),
                        pw.SizedBox(width: 10),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: Certificate.verifyUrl(certificate.code),
                          width: 64,
                          height: 64,
                          color: PdfPalette.ink,
                          drawText: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return doc.save();
}
