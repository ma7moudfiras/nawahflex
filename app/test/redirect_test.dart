import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/app/redirect.dart';
import 'package:nawahflex_app/app/sections.dart';
import 'package:nawahflex_app/features/auth/profile.dart';

/// بوّابة الروابط: من يُحوَّل إلى أين قبل أن يرى الصفحة المطلوبة.
void main() {
  const admin = Profile(id: 'a', role: 'admin');
  const trainer = Profile(id: 't', role: 'trainer');
  const viewer = Profile(id: 'v', role: 'viewer');
  const parent = Profile(id: 'p', role: 'parent');
  const student = Profile(id: 's', role: 'student');

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

  group('ولي الأمر', () {
    test('رئيسيته «أبنائي»', () {
      expect(go('/login', p: parent), '/kids');
      expect(go('/', p: parent), '/kids');
    });
    test('يفتح ملف ابنه برابطه المحفوظ', () {
      expect(go('/login?from=%2Fkids%2Fabc', p: parent), '/kids/abc');
      expect(go('/kids/abc', p: parent), isNull);
    });
    test('لا يصل إلى أقسام الموظفين ولا ملفات /students', () {
      expect(go('/students/abc', p: parent), '/kids');
      expect(go('/overview', p: parent), '/kids');
      expect(go('/sessions', p: parent), '/kids');
    });
    test('الموظفون لا يرون قسم الأهل', () {
      expect(go('/kids', p: admin), '/overview');
      expect(go('/kids/abc', p: trainer), '/sessions');
    });
  });

  group('الطالب', () {
    test('رئيسيته «ملفّي» ولا يصل لغيرها', () {
      expect(go('/login', p: student), '/me');
      expect(go('/me', p: student), isNull);
      expect(go('/students/abc', p: student), '/me');
      expect(go('/kids', p: student), '/me');
      expect(go('/kids/abc', p: student), '/me');
    });
  });

  test('المدرّب يرى قسماً واحداً، والإدارة كل الأقسام', () {
    expect(sectionsFor(trainer).map((s) => s.slug), ['sessions']);
    expect(sectionsFor(admin).length, allSections.length - 2); // كل شيء عدا «أبنائي» و«ملفّي»
    expect(sectionsFor(student).map((s) => s.slug), ['me']);
    expect(sectionsFor(parent).map((s) => s.slug), ['kids']);
  });

  test('روابط الأقسام فريدة', () {
    final slugs = allSections.map((s) => s.slug).toList();
    expect(slugs.toSet().length, slugs.length);
  });
}
