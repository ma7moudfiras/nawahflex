import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/supabase.dart';
import 'profile.dart';

/// حالة الجلسة والصلاحية، مشتركة عبر التطبيق.
///
/// الصلاحية تُقرأ من جدول profiles لا من بيانات المستخدم في auth — لأن
/// سياسات RLS في القاعدة تعتمد على هذا الجدول وحده، فتبقى الواجهة
/// والقاعدة متّفقتين على مصدر حقيقة واحد.
class AuthService extends ChangeNotifier {
  AuthService() {
    Db.auth.onAuthStateChange.listen((_) => _refresh());
    _refresh();
  }

  Profile? _profile;
  bool _loading = true;
  String? _error;

  Profile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isSignedIn => Db.isSignedIn;

  Future<void> _refresh() async {
    if (!Db.isSignedIn) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final row = await Db.client
          .from('profiles')
          .select('id, full_name, role')
          .eq('id', Db.user!.id)
          .maybeSingle();

      _profile = row == null ? null : Profile.fromMap(row);
      _error = null;
    } catch (e) {
      _profile = null;
      _error = 'تعذّر قراءة صلاحيتك: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await Db.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return _arabicError(e.message);
    } catch (e) {
      return 'تعذّر الاتصال بالخادم. تحقّق من اتصالك وحاول مجدداً.';
    }
  }

  Future<void> signOut() => Db.auth.signOut();

  /// ترجمة رسائل Supabase الشائعة — المستخدم عربي ولا يجب أن يرى إنجليزية.
  String _arabicError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة.';
    if (m.contains('email not confirmed')) return 'لم يُفعَّل البريد بعد. راجع رسالة التفعيل.';
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'محاولات كثيرة متتالية. انتظر قليلاً ثم أعد المحاولة.';
    }
    return 'تعذّر تسجيل الدخول. حاول مجدداً.';
  }
}
