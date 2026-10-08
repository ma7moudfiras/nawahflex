import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nawahflex_app/shared/app_shell.dart';
import 'package:nawahflex_app/shared/nav_item.dart';

/// الشريط السفلي على الجوّال: أربعة أقسام مثبّتة + «المزيد»، وقسم واحد بلا تنقّل.
void main() {
  NavItem item(String label, {bool pinned = false, int badge = 0}) => NavItem(
        label: label,
        icon: Icons.circle_outlined,
        selectedIcon: Icons.circle,
        pinned: pinned,
      ).withBadge(badge);

  final nine = [
    item('نظرة عامة', pinned: true),
    item('الرسائل', pinned: true),
    item('الطلاب', pinned: true),
    item('البرامج'),
    item('المدرّبون'),
    item('الأفواج'),
    item('المستحقات', badge: 2),
    item('مستحقات المدرّبين'),
    item('اللقاءات', pinned: true),
  ];

  Widget shell(Size size, List<NavItem> items, {int index = 0, ValueChanged<int>? onSelect}) =>
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: AppShell(
            items: items,
            index: index,
            onSelect: onSelect ?? (_) {},
            account: AccountInfo(
              displayName: 'مدرّب',
              roleLabel: 'مدرّب',
              initial: 'م',
              onSignOut: () {},
            ),
            title: items[index].label,
            child: const Text('المحتوى'),
          ),
        ),
      );

  const phone = Size(390, 844);

  testWidgets('تسعة أقسام → أربعة مثبّتة + «المزيد» في الشريط', (t) async {
    await t.pumpWidget(shell(phone, nine));
    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    expect(find.text('المزيد'), findsOneWidget);
    expect(find.text('البرامج'), findsNothing, reason: 'غير المثبَّت خلف «المزيد»');
  });

  testWidgets('«المزيد» يفتح الأقسام الباقية ويختار منها بفهرسها الأصلي', (t) async {
    int? picked;
    await t.pumpWidget(shell(phone, nine, onSelect: (i) => picked = i));
    await t.tap(find.text('المزيد'));
    await t.pumpAndSettle();
    for (final l in ['البرامج', 'المدرّبون', 'الأفواج', 'المستحقات', 'مستحقات المدرّبين']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    await t.tap(find.text('الأفواج'));
    await t.pumpAndSettle();
    expect(picked, 5);
  });

  testWidgets('قسم مفتوح من «المزيد» يظهر اسمه مكان «المزيد»', (t) async {
    await t.pumpWidget(shell(phone, nine, index: 3));
    expect(find.text('المزيد'), findsNothing);
    // مرة في العنوان ومرة في الشريط
    expect(find.text('البرامج'), findsNWidgets(2));
  });

  testWidgets('شارة الأقسام المخفية تظهر على «المزيد»', (t) async {
    await t.pumpWidget(shell(phone, nine));
    expect(find.text('2'), findsOneWidget);
  });

  group('قسم واحد (حساب المدرّب)', () {
    // NavigationBar و NavigationRail يشترطان عنصرين — كان التطبيق ينهار.
    final one = [item('اللقاءات', pinned: true)];

    testWidgets('الجوّال: بلا شريط سفلي ولا انهيار', (t) async {
      await t.pumpWidget(shell(phone, one));
      expect(t.takeException(), isNull);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('المحتوى'), findsOneWidget);
    });

    testWidgets('المكتب: بلا شريط جانبي ولا انهيار', (t) async {
      await t.pumpWidget(shell(const Size(1440, 900), one));
      expect(t.takeException(), isNull);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('المحتوى'), findsOneWidget);
    });
  });
}
