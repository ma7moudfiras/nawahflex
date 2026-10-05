import 'package:web/web.dart' as web;

/// على الويب: انتقال في التبويب نفسه — لا window.open (انظر open_url.dart).
Future<bool> openExternal(String url) async {
  if (url.isEmpty) return false;
  web.window.location.assign(url);
  return true;
}
