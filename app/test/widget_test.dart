import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/features/auth/profile.dart';
import 'package:nawahflex_app/features/messages/message.dart';
import 'package:nawahflex_app/shared/adaptive.dart';

void main() {
  group('Profile — الصلاحيات', () {
    Profile p(String role) => Profile(id: 'x', role: role, fullName: 'محمود فراس');

    test('المدير والمحرّر يديران، والبقية لا', () {
      expect(p('admin').canManage, isTrue);
      expect(p('editor').canManage, isTrue);
      expect(p('trainer').canManage, isFalse);
      expect(p('viewer').canManage, isFalse);
    });

    test('يطابق شرط private.is_admin في القاعدة', () {
      // السياسة في SQL: role in ('admin', 'editor')
      const dbRoles = {'admin', 'editor'};
      for (final r in ['admin', 'editor', 'trainer', 'viewer']) {
        expect(p(r).canManage, dbRoles.contains(r),
            reason: 'الدور $r يجب أن يطابق سياسة القاعدة');
      }
    });

    test('الاسم الفارغ لا يكسر الحرف الأول', () {
      const blank = Profile(id: 'x', role: 'admin', fullName: '   ');
      expect(blank.displayName, 'مستخدم');
      expect(blank.initial, isNotEmpty);
    });

    test('الحرف الأول يتعامل مع العربية بسلامة', () {
      expect(p('admin').initial, 'م');
    });
  });

  group('Message — رابط واتساب', () {
    Message m(String phone) => Message(
          id: 'x',
          name: 'اختبار',
          phone: phone,
          body: 'نص',
          status: 'new',
          createdAt: DateTime(2026, 1, 1),
        );

    test('الرقم المحلي يتحوّل لمفتاح فلسطين', () {
      expect(m('0599123456').whatsappUrl, 'https://wa.me/970599123456');
    });

    test('المسافات والرموز تُزال', () {
      expect(m('059 912-3456').whatsappUrl, 'https://wa.me/970599123456');
    });

    test('الصيغة الدولية بـ + تبقى كما هي', () {
      expect(m('+970599123456').whatsappUrl, 'https://wa.me/970599123456');
    });

    test('البادئة 00 تُزال', () {
      expect(m('00970599123456').whatsappUrl, 'https://wa.me/970599123456');
    });
  });

  group('Message — الحالات', () {
    test('كل حالة في القاعدة لها ترجمة عربية', () {
      // قيود CHECK في SQL: new, in_progress, done, spam
      for (final s in ['new', 'in_progress', 'done', 'spam']) {
        expect(Message.statusLabels.containsKey(s), isTrue,
            reason: 'الحالة $s بلا ترجمة');
      }
    });
  });

  group('التخطيط التكيّفي', () {
    Future<ScreenSize> sizeAt(WidgetTester tester, double width) async {
      late ScreenSize result;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(builder: (ctx) {
          result = ctx.screen;
          return const SizedBox();
        }),
      ));
      return result;
    }

    testWidgets('جوّال دون 720', (t) async {
      expect(await sizeAt(t, 390), ScreenSize.mobile);
      expect(await sizeAt(t, 719), ScreenSize.mobile);
    });

    testWidgets('لوحي بين 720 و1100', (t) async {
      expect(await sizeAt(t, 720), ScreenSize.tablet);
      expect(await sizeAt(t, 1099), ScreenSize.tablet);
    });

    testWidgets('مكتب من 1100', (t) async {
      expect(await sizeAt(t, 1100), ScreenSize.desktop);
      expect(await sizeAt(t, 1920), ScreenSize.desktop);
    });

    testWidgets('adaptive يتدرّج للأصغر عند غياب قيمة', (t) async {
      late int tablet, desktop;
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(800, 800)),
        child: Builder(builder: (ctx) {
          tablet = adaptive(ctx, mobile: 1);
          return const SizedBox();
        }),
      ));
      expect(tablet, 1, reason: 'اللوحي يرث قيمة الجوّال');

      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(1400, 800)),
        child: Builder(builder: (ctx) {
          desktop = adaptive(ctx, mobile: 1, tablet: 2);
          return const SizedBox();
        }),
      ));
      expect(desktop, 2, reason: 'المكتب يرث قيمة اللوحي');
    });
  });
}
