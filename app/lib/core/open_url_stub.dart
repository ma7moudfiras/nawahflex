import 'package:url_launcher/url_launcher.dart';

/// على الجوّال: يسلّم الرابط لتطبيق النظام. يرجع false إن تعذّر الفتح.
Future<bool> openExternal(String url) async {
  if (url.isEmpty) return false;
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
