import 'package:flutter/material.dart';

import '../features/attendance/attendance_screen.dart';
import '../features/auth/profile.dart';
import '../features/billing/student_dues_screen.dart';
import '../features/billing/trainer_payroll_screen.dart';
import '../features/cohorts/cohorts_screen.dart';
import '../features/dashboard/home_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/programs/programs_screen.dart';
import '../features/students/student_profile.dart';
import '../features/students/students_screen.dart';
import '../features/trainers/trainers_screen.dart';
import '../shared/nav_item.dart';

/// ما تحتاجه شاشات الأقسام من الهيكل: الحساب، وأعداد الرسائل، والتنقّل.
class SectionEnv {
  const SectionEnv({
    required this.profile,
    required this.counts,
    required this.go,
  });

  final Profile profile;

  /// أعداد الرسائل حسب الحالة — تملؤها شاشة الرسائل ويقرؤها الشريط والرئيسية.
  final ValueNotifier<Map<String, int>> counts;

  /// ينتقل إلى قسم بمعرّفه في الرابط (`messages`، `dues`…).
  final void Function(String slug) go;
}

/// قسم في البوابة — مصدر حقيقة واحد لرابطه، وعنصر تنقّله، ومن يراه، وشاشته.
///
/// كل قسم له رابط ثابت (`/app/students`)، فيعمل زر الرجوع في المتصفح،
/// ويُفتح الرابط المرسَل على واتساب على القسم نفسه بعد الدخول.
class Section {
  const Section({
    required this.slug,
    required this.item,
    required this.visibleTo,
    required this.build,
  });

  final String slug;
  final NavItem item;
  final bool Function(Profile p) visibleTo;
  final Widget Function(SectionEnv env) build;

  String get path => '/$slug';
}

bool _staff(Profile p) => p.canManage;
bool _marksAttendance(Profile p) => p.canManage || p.isTrainer;

/// كل أقسام البوابة بترتيب ظهورها. الإدارة والمحرّر يرون اللوحة كاملة؛
/// المدرّب يرى اللقاءات فقط — صلاحياته محصورة بحضور طلاب أفواجه (قرار
/// متَّخذ مسبقاً). الصلاحية الحقيقية في RLS؛ هذا للواجهة فقط.
final List<Section> allSections = [
  Section(
    slug: 'overview',
    item: const NavItem(
      label: 'نظرة عامة',
      pinned: true,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    visibleTo: _staff,
    build: (env) => ValueListenableBuilder(
      valueListenable: env.counts,
      builder: (_, counts, _) => HomeScreen(
        profile: env.profile,
        counts: counts,
        onGoToMessages: () => env.go('messages'),
        onGoToDues: () => env.go('dues'),
      ),
    ),
  ),
  Section(
    slug: 'messages',
    item: const NavItem(
      label: 'الرسائل',
      pinned: true,
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox,
    ),
    visibleTo: _staff,
    build: (env) => MessagesScreen(onCountsChanged: (c) => env.counts.value = c),
  ),
  Section(
    slug: 'students',
    item: const NavItem(
      label: 'الطلاب',
      pinned: true,
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
    ),
    visibleTo: _staff,
    build: (env) => StudentsScreen(viewer: env.profile),
  ),
  Section(
    slug: 'programs',
    item: const NavItem(
      label: 'البرامج',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
    ),
    visibleTo: _staff,
    build: (_) => const ProgramsScreen(),
  ),
  Section(
    slug: 'trainers',
    item: const NavItem(
      label: 'المدرّبون',
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge,
    ),
    visibleTo: _staff,
    build: (_) => const TrainersScreen(),
  ),
  Section(
    slug: 'cohorts',
    item: const NavItem(
      label: 'الأفواج',
      icon: Icons.groups_2_outlined,
      selectedIcon: Icons.groups_2,
    ),
    visibleTo: _staff,
    build: (_) => const CohortsScreen(),
  ),
  Section(
    slug: 'dues',
    item: const NavItem(
      label: 'المستحقات',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    visibleTo: _staff,
    build: (_) => const StudentDuesScreen(),
  ),
  Section(
    slug: 'payroll',
    item: const NavItem(
      label: 'مستحقات المدرّبين',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
    ),
    visibleTo: _staff,
    build: (_) => const TrainerPayrollScreen(),
  ),
  Section(
    slug: 'sessions',
    item: const NavItem(
      label: 'اللقاءات',
      pinned: true,
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
    ),
    visibleTo: _marksAttendance,
    build: (env) => AttendanceScreen(isAdmin: env.profile.canManage),
  ),
];

/// صفحة تفصيل تحت قسم (`/students/:id`). لها صلاحيتها الخاصة: المدرّب لا
/// يرى قسم الطلاب، لكنه يفتح ملف طالب من فوجه ليمنحه شارة أو يقيّم مهارة.
class DetailRoute {
  const DetailRoute({
    required this.section,
    required this.visibleTo,
    required this.build,
  });

  final String section;
  final bool Function(Profile p) visibleTo;
  final Widget Function(SectionEnv env, String id) build;

  String get path => '/$section/:id';

  bool matches(List<String> segments) =>
      segments.length == 2 && segments.first == section;
}

final List<DetailRoute> detailRoutes = [
  DetailRoute(
    section: 'students',
    visibleTo: _marksAttendance,
    build: (env, id) => StudentProfileView(studentId: id, viewer: env.profile),
  ),
];

/// الأقسام التي يراها هذا الحساب، بترتيبها.
List<Section> sectionsFor(Profile p) =>
    allSections.where((s) => s.visibleTo(p)).toList();

/// هل يدخل هذا الحساب البوابة أصلاً؟ (قسم واحد على الأقل)
bool hasPortalAccess(Profile? p) => p != null && sectionsFor(p).isNotEmpty;

/// أول قسم يراه الحساب — وجهته بعد الدخول وعند رابط لا يملك صلاحيته.
String homePathFor(Profile p) => sectionsFor(p).first.path;
