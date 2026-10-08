// ============================================================================
// الهوية في ملفات PDF (الشهادة والتقرير الشهري)
// ----------------------------------------------------------------------------
// - الخطوط نفسها المضمَّنة في التطبيق (assets/fonts) — لا تنزيل من الشبكة.
// - الشعار SVG مولّد من هندسة logo.dart نفسها، بألوان tokens.dart — متّجه
//   حادّ في الطباعة، ولا صورة PNG تكبّر الملف.
// - الألوان من NawahColors فقط، كما في باقي التطبيق.
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../shared/months.dart';
import 'tokens.dart';

PdfColor pdfColor(Color c) => PdfColor.fromInt(c.toARGB32());

class PdfPalette {
  PdfPalette._();
  static final ink = pdfColor(NawahColors.ink);
  static final inkTint = pdfColor(NawahColors.inkTint);
  static final paper = pdfColor(NawahColors.paper);
  static final accent = pdfColor(NawahColors.accent);
  static final accentInk = pdfColor(NawahColors.accentInk);
  static final accentSoft = pdfColor(NawahColors.accentSoft);
  static final border = pdfColor(NawahColors.border);
  static final textSoft = pdfColor(NawahColors.textSoft);
  static final textMuted = pdfColor(NawahColors.textMuted);
  static final ok = pdfColor(NawahColors.ok);
  static final err = pdfColor(NawahColors.err);
}

/// خطوط الهوية محمَّلة — تُمرَّر لبُناة الملفات فيمكن اختبارها دون rootBundle.
class PdfFonts {
  const PdfFonts({required this.body, required this.bodyBold, required this.display, required this.displayBold});

  final pw.Font body;
  final pw.Font bodyBold;
  final pw.Font display;
  final pw.Font displayBold;

  static const files = (
    body: 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    bodyBold: 'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    display: 'assets/fonts/Alexandria-Bold.ttf',
    displayBold: 'assets/fonts/Alexandria-ExtraBold.ttf',
  );

  static PdfFonts? _cache;

  /// من حزمة التطبيق، مرة واحدة في الجلسة.
  static Future<PdfFonts> load() async {
    if (_cache != null) return _cache!;
    Future<pw.Font> f(String path) async => pw.Font.ttf(await rootBundle.load(path));
    return _cache = PdfFonts(
      body: await f(files.body),
      bodyBold: await f(files.bodyBold),
      display: await f(files.display),
      displayBold: await f(files.displayBold),
    );
  }

  /// من بايتات جاهزة (الاختبارات تقرأ الملفات مباشرة).
  factory PdfFonts.fromBytes({
    required Uint8List body,
    required Uint8List bodyBold,
    required Uint8List display,
    required Uint8List displayBold,
  }) =>
      PdfFonts(
        body: pw.Font.ttf(ByteData.sublistView(body)),
        bodyBold: pw.Font.ttf(ByteData.sublistView(bodyBold)),
        display: pw.Font.ttf(ByteData.sublistView(display)),
        displayBold: pw.Font.ttf(ByteData.sublistView(displayBold)),
      );

  pw.ThemeData get theme => pw.ThemeData.withFont(base: body, bold: bodyBold);
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// الشعار (وجه الروبوت) SVG — نفس مسارات logo.dart و brand/nawah-logo-navy.svg.
String nawahLogoSvg({Color ink = NawahColors.ink, Color dot = NawahColors.accent}) {
  final i = _hex(ink), d = _hex(dot);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-564.5 -1619 2685 2440">'
      '<path d="M955 -1192 L1653.5 -1192 A300 300 0 0 1 1953.5 -892" fill="none" stroke="$i" stroke-width="174"/>'
      '<path d="M1953.5 90 L1953.5 354 A300 300 0 0 1 1653.5 654 L-97.5 654 A300 300 0 0 1 -397.5 354 L-397.5 -892 A300 300 0 0 1 -97.5 -1192 L601 -1192" fill="none" stroke="$i" stroke-width="174"/>'
      '<rect x="691" y="-1539" width="174" height="1539" fill="$i"/>'
      '<path d="M21 -290 A290 290 0 1 0 601 -290 A290 290 0 1 0 21 -290 Z M193 -290 A118 118 0 1 1 429 -290 A118 118 0 1 1 193 -290 Z" fill="$i" fill-rule="evenodd"/>'
      '<circle cx="226" cy="-726" r="76" fill="$d"/>'
      '<circle cx="396" cy="-726" r="76" fill="$d"/>'
      '<path d="M955 -290 A290 290 0 1 0 1535 -290 A290 290 0 1 0 955 -290 Z M1127 -290 A118 118 0 1 1 1363 -290 A118 118 0 1 1 1127 -290 Z" fill="$i" fill-rule="evenodd"/>'
      '<path d="M1953.5 -560 L1953.5 -307 A220 220 0 0 1 1733.5 -87 L1361 -87" fill="none" stroke="$i" stroke-width="174"/>'
      '<path d="M1448 -290 L1448 90 A220 220 0 0 1 1228 310 L409.2 310 A220 220 0 0 1 189.2 90 L189.2 87.9" fill="none" stroke="$i" stroke-width="174" stroke-linejoin="round"/>'
      '<circle cx="1953.5" cy="-726" r="76" fill="$d"/>'
      '</svg>';
}

/// «7 تشرين الأول 2026» بأرقام لاتينية — بلا اعتماد على تهيئة intl.
String pdfDate(DateTime d) => '${d.day} ${arabicMonthNames[d.month - 1]} ${d.year}';
