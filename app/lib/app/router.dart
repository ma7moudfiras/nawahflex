import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../brand/tokens.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/change_password_dialog.dart';
import '../features/auth/login_screen.dart';
import '../features/notifications/notification_bell.dart';
import '../features/notifications/notifications_repository.dart';
import '../shared/app_shell.dart';
import 'gate_screens.dart';
import 'redirect.dart';
import 'sections.dart';

/// موجّه البوابة: رابط لكل قسم (`/app/students`)، وبوّابة دخول تحفظ الرابط
/// المطلوب، وأقسام تظهر حسب الدور. يُعاد تقييمه كلما تغيّرت الجلسة.
GoRouter buildPortalRouter(AuthService auth, ValueNotifier<Map<String, int>> counts) {
  return GoRouter(
    refreshListenable: auth,
    // رابط بلا صفحة (`/students/x/y`) يعود للرئيسية بدل صفحة خطأ إنجليزية.
    onException: (_, _, router) => router.go('/'),
    redirect: (context, state) => portalRedirect(
      uri: state.uri,
      signedIn: auth.isSignedIn,
      loading: auth.loading,
      failed: auth.error != null,
      profile: auth.profile,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Loading()),
      GoRoute(path: loginPath, builder: (_, _) => LoginScreen(auth: auth)),
      GoRoute(path: blockedPath, builder: (_, _) => BlockedScreen(auth: auth)),
      ShellRoute(
        builder: (context, state, child) => _PortalShell(
          auth: auth,
          counts: counts,
          location: state.uri.path,
          child: child,
        ),
        routes: [
          for (final s in allSections)
            GoRoute(
              path: s.path,
              // تبديل القسم لا يحتاج حركة انتقال — كما كان قبل الروابط.
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: _SectionPage(auth: auth, counts: counts, section: s),
              ),
            ),
          for (final r in detailRoutes)
            GoRoute(
              path: r.path,
              builder: (context, state) => _DetailPage(
                auth: auth,
                counts: counts,
                route: r,
                id: state.pathParameters['id']!,
              ),
            ),
        ],
      ),
    ],
  );
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.auth, required this.counts, required this.route, required this.id});
  final AuthService auth;
  final ValueNotifier<Map<String, int>> counts;
  final DetailRoute route;
  final String id;

  @override
  Widget build(BuildContext context) {
    final p = auth.profile;
    if (p == null) return const SizedBox.shrink();
    return Material(
      color: NawahColors.paper,
      child: route.build(SectionEnv(profile: p, counts: counts, go: (slug) => context.go('/$slug')), id),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.auth, required this.counts, required this.section});
  final AuthService auth;
  final ValueNotifier<Map<String, int>> counts;
  final Section section;

  @override
  Widget build(BuildContext context) {
    final p = auth.profile;
    // أثناء إعادة قراءة الصلاحية يبقى الرابط كما هو؛ لا شيء يُعرض بعد.
    if (p == null) return const SizedBox.shrink();
    return section.build(SectionEnv(
      profile: p,
      counts: counts,
      go: (slug) => context.go('/$slug'),
    ));
  }
}

/// الهيكل التكيّفي حول القسم الحالي — يقرأ القسم من الرابط لا من فهرس محفوظ.
class _PortalShell extends StatelessWidget {
  const _PortalShell({
    required this.auth,
    required this.counts,
    required this.location,
    required this.child,
  });

  final AuthService auth;
  final ValueNotifier<Map<String, int>> counts;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = auth.profile;
    if (auth.loading || p == null) return const _Loading();

    final sections = sectionsFor(p);
    final first = Uri(path: location).pathSegments.firstOrNull;
    final index = sections.indexWhere((s) => s.slug == first).clamp(0, sections.length - 1);

    return ValueListenableBuilder(
      valueListenable: counts,
      builder: (context, c, _) {
        final items = [
          for (final s in sections)
            s.slug == 'messages' ? s.item.withBadge(c['new'] ?? 0) : s.item,
        ];
        return Title(
          title: '${items[index].label} — أكاديمية نواة',
          color: NawahColors.ink,
          child: AppShell(
            items: items,
            index: index,
            onSelect: (i) => context.go(sections[i].path),
            account: AccountInfo(
              displayName: p.displayName,
              roleLabel: p.roleLabel,
              initial: p.initial,
              // اشتراك Push لهذا الجهاز يُحذف قبل الخروج — فلا تصل إشعارات
              // هذا المستخدم لمن يدخل بعده على الجهاز نفسه.
              onSignOut: () async {
                await const NotificationsRepository().forgetThisDevice();
                await auth.signOut();
              },
              onChangePassword: showChangePasswordSheet,
            ),
            actions: [
              if (p.isParent || p.isStudent)
                NotificationBell(
                  isParent: p.isParent,
                  isStudent: p.isStudent,
                  onOpen: (path) => context.go(path),
                ),
            ],
            title: items[index].label,
            child: child,
          ),
        );
      },
    );
  }
}
