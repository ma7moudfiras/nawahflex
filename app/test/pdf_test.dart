import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nawahflex_app/brand/pdf_brand.dart';
import 'package:nawahflex_app/features/certificates/certificate.dart';
import 'package:nawahflex_app/features/certificates/certificate_pdf.dart';
import 'package:nawahflex_app/features/progress/progress_models.dart';
import 'package:nawahflex_app/features/reports/monthly_report.dart';
import 'package:nawahflex_app/features/reports/monthly_report_pdf.dart';

PdfFonts _fonts() {
  final f = PdfFonts.files;
  return PdfFonts.fromBytes(
    body: File(f.body).readAsBytesSync(),
    bodyBold: File(f.bodyBold).readAsBytesSync(),
    display: File(f.display).readAsBytesSync(),
    displayBold: File(f.displayBold).readAsBytesSync(),
  );
}

/// يحفظ الملف حين يُطلب (PDF_OUT=مجلد) لمعاينته بالعين.
void _maybeSave(String name, List<int> bytes) {
  final dir = Platform.environment['PDF_OUT'];
  if (dir != null) File('$dir/$name').writeAsBytesSync(bytes);
}

void main() {
  final cert = Certificate(
    id: 'c1',
    code: 'NW-AB3D-7KQX',
    studentId: 's1',
    kind: 'program',
    title: 'إتمام برنامج الروبوتات — المستوى الأول (٣٢ ساعة)',
    issuedAt: DateTime(2026, 10, 7),
  );

  group('Certificate', () {
    test('code pattern matches the server check', () {
      expect(Certificate.codePattern.hasMatch('NW-AB3D-7KQX'), isTrue);
      expect(Certificate.codePattern.hasMatch('nw-ab3d-7kqx'), isFalse);
      expect(Certificate.codePattern.hasMatch('NW-AB3D7KQX'), isFalse);
    });

    test('verify url carries the code', () {
      expect(Certificate.verifyUrl(cert.code), 'https://www.nawahflex.org/verify?c=NW-AB3D-7KQX');
    });

    test('fromMap parses revoked state', () {
      final c = Certificate.fromMap({
        'id': 'x', 'code': 'NW-AAAA-BBBB', 'student_id': 's', 'kind': 'level', 'title': 't',
        'program_id': null, 'level': 3, 'issued_at': '2026-10-01T10:00:00Z', 'revoked_at': '2026-10-02T10:00:00Z',
      });
      expect(c.isRevoked, isTrue);
      expect(c.level, 3);
    });
  });

  test('certificate PDF builds', () async {
    final bytes = await buildCertificatePdf(certificate: cert, studentName: 'ديار أحمد', fonts: _fonts());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    _maybeSave('certificate.pdf', bytes);
  });

  test('pdfDate uses Levantine month names', () {
    expect(pdfDate(DateTime(2026, 10, 7)), '7 تشرين الأول 2026');
  });

  group('MonthlyReport', () {
    final oct = DateTime(2026, 10);
    MonthlyReport build() => MonthlyReport.build(
          month: DateTime(2026, 10, 19),
          studentName: 'ديار أحمد',
          progress: const StudentProgress(
            studentId: 's1', points: 140, level: 3, levelTitle: 'دائرة', levelMinPoints: 100, nextLevelPoints: 250),
          attendance: [
            (date: DateTime(2026, 10, 2), status: 'present'),
            (date: DateTime(2026, 10, 9), status: 'late'),
            (date: DateTime(2026, 10, 16), status: 'absent'),
            (date: DateTime(2026, 10, 23), status: 'excused'),
            (date: DateTime(2026, 9, 25), status: 'present'), // شهر آخر
          ],
          catalog: const [
            BadgeDef(id: 'b1', key: 'k1', title: 'أول روبوت يتحرّك', description: '', icon: 'robot', points: 20),
            BadgeDef(id: 'b2', key: 'k2', title: 'قائد فريق', description: '', icon: 'lead', points: 20),
          ],
          earned: [
            EarnedBadge(id: 'e1', badgeId: 'b1', awardedAt: DateTime(2026, 10, 9)),
            EarnedBadge(id: 'e2', badgeId: 'b2', awardedAt: DateTime(2026, 8, 1)),
          ],
          projects: [
            StudentProject(id: 'p1', studentId: 's1', title: 'سيارة تتبع الخط', createdAt: DateTime(2026, 10, 12), rating: 4),
          ],
          skills: const [
            Skill(id: 'k1', programId: 'g', title: 'التجميع الميكانيكي'),
            Skill(id: 'k2', programId: 'g', title: 'البرمجة بالكتل'),
          ],
          skillLevels: const {'k1': 3},
          notes: [
            StudentNote(id: 'n1', body: 'تحسّن واضح في العمل ضمن الفريق.', createdAt: DateTime(2026, 10, 10), visibleToGuardian: true),
            StudentNote(id: 'n2', body: 'ملاحظة داخلية', createdAt: DateTime(2026, 10, 11), visibleToGuardian: false),
          ],
        );

    test('keeps only the chosen month', () {
      final r = build();
      expect(r.month, oct);
      expect(r.attendance, hasLength(4));
      expect(r.badges.map((b) => b.title), ['أول روبوت يتحرّك']);
      expect(r.projects, hasLength(1));
    });

    test('never includes internal notes', () {
      expect(build().notes.map((n) => n.body), ['تحسّن واضح في العمل ضمن الفريق.']);
    });

    test('rate counts present and late', () {
      final r = build();
      expect(r.attended, 2);
      expect(r.attendanceRate, 50);
    });

    test('recentMonths crosses the year boundary', () {
      expect(MonthlyReport.recentMonths(DateTime(2026, 2, 15), count: 3),
          [DateTime(2026, 2), DateTime(2026, 1), DateTime(2025, 12)]);
    });

    test('report PDF builds', () async {
      final bytes = await buildMonthlyReportPdf(report: build(), fonts: _fonts(), generatedAt: DateTime(2026, 10, 31));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      _maybeSave('report.pdf', bytes);
    });

    test('empty month still builds', () async {
      final r = MonthlyReport.build(
        month: oct, studentName: 'س', progress: const StudentProgress.empty('s'), attendance: const [],
        catalog: const [], earned: const [], projects: const [], skills: const [], skillLevels: const {}, notes: const [],
      );
      expect(r.attendanceRate, isNull);
      expect(await buildMonthlyReportPdf(report: r, fonts: _fonts()), isNotEmpty);
    });
  });
}
