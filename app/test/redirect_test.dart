import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/app/redirect.dart';
import 'package:nawahflex_app/app/sections.dart';
import 'package:nawahflex_app/features/auth/profile.dart';

/// بوّابة الروابط: من يُحوَّل إلى أين قبل أن يرى الصفحة المطلوبة.
void main() {
  const admin = Profile(id: 'a', role: 'admin');
  const trainer = Profile(id: 't', role: 'trainer');
  const viewer = Profile(id: 'v', role: 'viewer');

  String? go(String url, {bool signedIn = true, bool loading = false, bool failed = false, Profile? p}) =>
      portalRedirect(
        uri: Uri.parse(url),
        signedIn: signedIn,
        loading: loading,
        failed: failed,
        profile: p,
      );

  group('غير المسجَّل', () {
    test('يذهب للدخول ويُحفظ الرابط المطلوب', () {
      expect(go('/students', signedIn: false), '/login?from=%2Fstudents');
    });
    test('الجذر يذهب للدخول بلا from', () {
      expect(go('/', signedIn: false), '/login');
    });
    test('يبقى في شاشة الدخول', () {
      expect(go('/login?from=%2Fdues', signedIn: false), isNull);
    });
  });

  group('المسجَّل', () {
    test('ينتظر قراءة الصلاحية دون تحويل', () {
      expect(go('/students', loading: true), isNull);
    });
    test('بعد الدخول يصل للرابط المحفوظ', () {
      expect(go('/login?from=%2Fdues', p: admin), '/dues');
    });
    test('بعد الدخول بلا رابط محفوظ يصل لرئيسية دوره', () {
      expect(go('/login', p: admin), '/overview');
      expect(go('/', p: trainer), '/sessions');
    });
    test('رابط محفوظ لقسم لا يملكه يُستبدل برئيسيته', () {
      expect(go('/login?from=%2Fdues', p: trainer), '/sessions');
    });
    test('قسم لا يملكه يعود لرئيسيته', () {
      expect(go('/students', p: trainer), '/sessions');
      expect(go('/nothing', p: admin), '/overview');
    });
    test('المدرّب يفتح ملف طالب لكن لا قائمة الطلاب', () {
      expect(go('/students/123', p: trainer), isNull);
      expect(go('/students', p: trainer), '/sessions');
      expect(go('/students/1/2', p: trainer), '/sessions');
    });
    test('قسمه ومساراته الفرعية مسموحة', () {
      expect(go('/students', p: admin), isNull);
      expect(go('/students/123', p: admin), isNull);
      expect(go('/sessions', p: trainer), isNull);
    });
    test('دور بلا أقسام أو تعذّر قراءة الصلاحية → شاشة الحجب', () {
      expect(go('/overview', p: viewer), '/blocked');
      expect(go('/overview', failed: true), '/blocked');
      expect(go('/blocked', p: viewer), isNull);
    });
  });

  test('المدرّب يرى قسماً واحداً، والإدارة كل الأقسام', () {
    expect(sectionsFor(trainer).map((s) => s.slug), ['sessions']);
    expect(sectionsFor(admin).length, allSections.length);
  });

  test('روابط الأقسام فريدة', () {
    final slugs = allSections.map((s) => s.slug).toList();
    expect(slugs.toSet().length, slugs.length);
  });
}
