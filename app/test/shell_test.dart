import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/shared/app_shell.dart';
import 'package:nawahflex_app/shared/nav_item.dart';

/// اختبارات الهيكل التكيّفي.
///
/// هذا هو الادّعاء المركزي في التطبيق: كود واحد يخدم الإدارة على المكتب
/// وأولياء الأمور على الجوّال. الاختبارات هنا تتحقّق منه فعلياً بدل الاكتفاء
/// بالنظر إلى لقطة شاشة.
void main() {
  var signedOut = false;

  Widget shell(Size size, {int index = 0}) => MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: AppShell(
            items: [
              const NavItem(
                label: 'نظرة عامة',
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
              ),
              const NavItem(
                label: 'الرسائل',
                icon: Icons.inbox_outlined,
                selectedIcon: Icons.inbox,
              ).withBadge(3),
            ],
            index: index,
            onSelect: (_) {},
            account: AccountInfo(
              displayName: 'محمود فراس',
              roleLabel: 'مدير',
              initial: 'م',
              onSignOut: () => signedOut = true,
            ),
            title: 'نظرة عامة',
            child: const Text('المحتوى'),
          ),
        ),
      );

  setUp(() => signedOut = false);

  group('الجوّال (390px)', () {
    testWidgets('يعرض شريط تنقّل سفلي لا شريطاً جانبياً', (t) async {
      await t.pumpWidget(shell(const Size(390, 844)));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('المحتوى يظهر', (t) async {
      await t.pumpWidget(shell(const Size(390, 844)));
      expect(find.text('المحتوى'), findsOneWidget);
    });
  });

  group('اللوحي (820px)', () {
    testWidgets('ينتقل إلى الشريط الجانبي غير الممدَّد', (t) async {
      await t.pumpWidget(shell(const Size(820, 1100)));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final rail = t.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse, reason: 'اللوحي ضيّق — الشريط لا يتمدّد');
    });
  });

  group('المكتب (1440px)', () {
    testWidgets('شريط جانبي ممدَّد باسم الأكاديمية', (t) async {
      await t.pumpWidget(shell(const Size(1440, 900)));
      final rail = t.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.text('نواة فليكس'), findsOneWidget);
      expect(find.text('لوحة الإدارة'), findsOneWidget);
    });

    testWidgets('يعرض شريطاً علوياً بعنوان الشاشة', (t) async {
      await t.pumpWidget(shell(const Size(1440, 900)));
      expect(find.text('نظرة عامة'), findsWidgets);
    });
  });

  group('عبر الأحجام', () {
    testWidgets('شارة العدد تظهر في الوضعين', (t) async {
      for (final size in [const Size(390, 844), const Size(1440, 900)]) {
        await t.pumpWidget(shell(size));
        expect(find.byType(Badge), findsWidgets,
            reason: 'شارة الرسائل الجديدة مفقودة عند ${size.width}px');
      }
    });

    testWidgets('اسم المستخدم يظهر على المكتب', (t) async {
      await t.pumpWidget(shell(const Size(1440, 900)));
      expect(find.text('محمود فراس'), findsOneWidget);
    });

    testWidgets('تسجيل الخروج يستدعي المُعالِج', (t) async {
      await t.pumpWidget(shell(const Size(1440, 900)));
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('تسجيل الخروج'));
      await t.pumpAndSettle();
      expect(signedOut, isTrue);
    });
  });
}
