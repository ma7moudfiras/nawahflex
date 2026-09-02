import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'brand/tokens.dart';
import 'core/reload.dart';
import 'core/supabase.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/cohorts/cohorts_screen.dart';
import 'features/dashboard/home_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/programs/programs_screen.dart';
import 'features/students/students_screen.dart';
import 'shared/app_shell.dart';
import 'shared/nav_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التطبيق عربي بالكامل. نثبّت لغة intl صراحةً بدل الاعتماد على ما يبلّغه
  // المتصفح — بعض المتصفحات تبلّغ لغة فارغة أو غير قابلة للتحليل فيرمي
  // intl خطأ «Incorrect locale information provided» وتبقى الشاشة بيضاء.
  Intl.defaultLocale = 'ar';

  // لا يُنتظر التهيئة قبل runApp بلا حدّ: لو تعذّر الوصول إلى Supabase
  // (لا إنترنت، أو الخدمة متوقّفة) لبقي المستخدم أمام شاشة بيضاء بلا أي
  // تفسير. نمهله وقتاً معقولاً ثم نُقلع على كل حال ونعرض خطأً واضحاً.
  String? bootError;
  try {
    await Db.init().timeout(const Duration(seconds: 15));
  } on TimeoutException {
    bootError = 'استغرق الاتصال بالخادم وقتاً طويلاً. تحقّق من اتصالك بالإنترنت.';
  } catch (e) {
    bootError = 'تعذّر الاتصال بخادم الأكاديمية. حاول مجدداً بعد قليل.';
  }

  runApp(NawahApp(bootError: bootError));
}

class NawahApp extends StatefulWidget {
  const NawahApp({super.key, this.bootError});

  /// خطأ وقع أثناء الإقلاع — يُعرض بدل اللوحة.
  final String? bootError;

  @override
  State<NawahApp> createState() => _NawahAppState();
}

class _NawahAppState extends State<NawahApp> {
  AuthService? _auth;

  @override
  void initState() {
    super.initState();
    // AuthService يفترض أن Supabase مُهيّأ؛ لا نبنيه إن فشل الإقلاع.
    if (widget.bootError == null) {
      _auth = AuthService()..addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() => setState(() {});

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نواة فليكس — لوحة الإدارة',
      debugShowCheckedModeBanner: false,
      theme: NawahTheme.light,

      // التطبيق عربي بالكامل — RTL أصيل لا معكوس
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: widget.bootError != null
          ? _BootError(message: widget.bootError!)
          : _Gate(auth: _auth!),
    );
  }
}

/// شاشة فشل الإقلاع — أفضل بكثير من شاشة بيضاء صامتة.
class _BootError extends StatelessWidget {
  const _BootError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NawahColors.ink,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 46, color: Color(0xFF6B7A9C)),
                const SizedBox(height: NawahSpacing.s4),
                const Text('تعذّر تشغيل اللوحة',
                    style: TextStyle(
                      fontFamily: NawahFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: Colors.white,
                    )),
                const SizedBox(height: NawahSpacing.s2),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF93A2C2), height: 1.8)),
                const SizedBox(height: NawahSpacing.s5),
                FilledButton.icon(
                  // إعادة التحميل تعيد تشغيل main من جديد
                  onPressed: () => reloadApp(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يقرّر ما يراه المستخدم: شاشة دخول، أو لوحة، أو رفض صلاحية.
class _Gate extends StatelessWidget {
  const _Gate({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    if (!auth.isSignedIn) return LoginScreen(auth: auth);

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // الصلاحية تُفحص هنا للواجهة، لكن الحماية الحقيقية في RLS —
    // حتى لو تجاوز أحدهم هذه الشاشة، لن يعيد له الخادم صفاً واحداً.
    // المدرّب يدخل أيضاً (لشاشة الحضور فقط) — وليس الإدارة/التحرير حصراً.
    final p = auth.profile;
    if (p == null || !(p.canManage || p.isTrainer)) {
      return _NoAccess(auth: auth);
    }

    return DashboardShell(auth: auth);
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 46, color: NawahColors.textMuted),
              const SizedBox(height: NawahSpacing.s4),
              const Text('لا تملك صلاحية الدخول للوحة',
                  style: TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s2),
              Text(
                'حسابك (${auth.profile?.roleLabel ?? 'غير معروف'}) لا يملك صلاحية '
                'الإدارة. تواصل مع مدير الأكاديمية لترقية حسابك.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: NawahColors.textSoft, height: 1.8),
              ),
              const SizedBox(height: NawahSpacing.s5),
              OutlinedButton.icon(
                onPressed: auth.signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// اللوحة نفسها — تنقّل بين الأقسام داخل هيكل تكيّفي واحد.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.auth});
  final AuthService auth;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;
  Map<String, int> _counts = const {};

  void _onCounts(Map<String, int> c) {
    if (mounted) setState(() => _counts = c);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.auth.profile;
    // المدرّب يرى شاشة الحضور فقط — صلاحياته محصورة بحضور طلاب أفواجه،
    // لا إدارة الطلاب/البرامج/الأفواج نفسها (قرار متَّخذ مسبقاً). الإدارة
    // والمحرّر يرون اللوحة كاملة، وشاشة الحضور أيضاً لتتبّع/تصحيح يدوي.
    final canManage = p?.canManage ?? false;
    final canMarkAttendance = canManage || (p?.isTrainer ?? false);

    final items = <NavItem>[
      if (canManage)
        const NavItem(
          label: 'نظرة عامة',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
      if (canManage)
        NavItem(
          label: 'الرسائل',
          icon: Icons.inbox_outlined,
          selectedIcon: Icons.inbox,
        ).withBadge(_counts['new'] ?? 0),
      if (canManage)
        const NavItem(
          label: 'الطلاب',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
        ),
      if (canManage)
        const NavItem(
          label: 'البرامج',
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
        ),
      if (canManage)
        const NavItem(
          label: 'الأفواج',
          icon: Icons.groups_2_outlined,
          selectedIcon: Icons.groups_2,
        ),
      if (canMarkAttendance)
        const NavItem(
          label: 'الحضور',
          icon: Icons.checklist_outlined,
          selectedIcon: Icons.checklist,
        ),
    ];

    final screens = <Widget>[
      if (canManage)
        HomeScreen(
          profile: widget.auth.profile,
          counts: _counts,
          onGoToMessages: () => setState(() => _index = 1),
        ),
      if (canManage) MessagesScreen(onCountsChanged: _onCounts),
      if (canManage) const StudentsScreen(),
      if (canManage) const ProgramsScreen(),
      if (canManage) const CohortsScreen(),
      if (canMarkAttendance) const AttendanceScreen(),
    ];

    // فهرس آمن دائماً: صلاحية المستخدم (وبالتالي طول القوائم أعلاه) قد
    // تتغيّر بين بناء وآخر بلا إعادة تشغيل التطبيق.
    final index = _index < items.length ? _index : 0;

    return AppShell(
      items: items,
      index: index,
      onSelect: (i) => setState(() => _index = i),
      account: AccountInfo(
        displayName: p?.displayName ?? '—',
        roleLabel: p?.roleLabel ?? '',
        initial: p?.initial ?? '؟',
        onSignOut: widget.auth.signOut,
      ),
      title: items[index].label,
      child: screens[index],
    );
  }
}
