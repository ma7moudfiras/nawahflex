import '../features/auth/profile.dart';
import 'sections.dart';

const loginPath = '/login';
const blockedPath = '/blocked';

/// أين يذهب المستخدم قبل أن يرى الرابط المطلوب — أو null ليبقى حيث هو.
///
/// دالة خالصة بلا Supabase كي تُختبر كل حالاتها دون شبكة. الرابط المطلوب
/// يُحفظ في `from` عبر شاشة الدخول، فيصل ولي الأمر أو المدرّب إلى الصفحة
/// التي أُرسل رابطها إليه، لا إلى الرئيسية.
String? portalRedirect({
  required Uri uri,
  required bool signedIn,
  required bool loading,
  required bool failed,
  required Profile? profile,
}) {
  final path = uri.path;
  final atGate = path == loginPath || path == blockedPath;

  if (!signedIn) {
    if (path == loginPath) return null;
    final from = atGate || path == '/' ? null : uri.toString();
    return Uri(path: loginPath, queryParameters: from == null ? null : {'from': from})
        .toString();
  }

  // الصلاحية لم تُقرأ بعد — نبقى مكاننا؛ الهيكل يعرض مؤشّر تحميل.
  if (loading) return null;

  if (failed || !hasPortalAccess(profile)) {
    return path == blockedPath ? null : blockedPath;
  }

  final p = profile!;
  final home = homePathFor(p);
  if (atGate || path == '/') {
    final from = uri.queryParameters['from'];
    return (from != null && _allowed(Uri.parse(from).path, p)) ? from : home;
  }
  return _allowed(path, p) ? null : home;
}

/// هل يملك الحساب قسم هذا الرابط؟ (`/students/…` يتبع قسم الطلاب)
bool _allowed(String path, Profile p) {
  final segments = Uri(path: path).pathSegments;
  if (segments.isEmpty) return false;
  if (sectionsFor(p).any((s) => s.slug == segments.first)) return true;
  return detailRoutes.any((r) => r.matches(segments) && r.visibleTo(p));
}
