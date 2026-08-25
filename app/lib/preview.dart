// نقطة دخول للمعاينة البصرية فقط — تعرض اللوحة ببيانات ثابتة ودون شبكة،
// كي يمكن تفقّد التخطيط على كل المقاسات. لا تدخل في بناء الإنتاج.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'brand/tokens.dart';
import 'features/dashboard/home_screen.dart';
import 'features/auth/profile.dart';
import 'shared/app_shell.dart';
import 'shared/nav_item.dart';

void main() {
  Intl.defaultLocale = 'ar';
  runApp(const _Preview());
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    const profile = Profile(id: 'x', role: 'admin', fullName: 'محمود فراس');
    const counts = {'all': 47, 'new': 5, 'in_progress': 3, 'done': 38, 'spam': 1};

    final items = [
      const NavItem(label: 'نظرة عامة', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
      const NavItem(label: 'الرسائل', icon: Icons.inbox_outlined, selectedIcon: Icons.inbox).withBadge(5),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NawahTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(
        items: items,
        index: _i,
        onSelect: (i) => setState(() => _i = i),
        account: AccountInfo(
          displayName: profile.displayName,
          roleLabel: profile.roleLabel,
          initial: profile.initial,
          onSignOut: () {},
        ),
        title: items[_i].label,
        child: HomeScreen(
          profile: profile,
          counts: counts,
          onGoToMessages: () => setState(() => _i = 1),
        ),
      ),
    );
  }
}
