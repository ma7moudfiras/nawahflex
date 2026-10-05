import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import 'error_reporter.dart';

/// التعديل لم يمسّ أي صف — RLS رفضه بصمت، أو السجل حُذف في الأثناء.
///
/// PostgREST لا يرمي خطأً حين ترفض سياسة RLS تعديلاً أو حذفاً: يرجع
/// قائمة فارغة فقط. بدون فحص صريح يرى المستخدم «تم الحفظ» ولم يُحفظ شيء.
/// لذلك كل update/delete على صف واحد يمرّ عبر [expectRows].
class WriteDenied implements Exception {
  const WriteDenied();
  @override
  String toString() => 'WriteDenied';
}

/// يتحقّق أن الكتابة أصابت صفاً واحداً على الأقل. الاستعمال:
///   `expectRows(await q.update(v).eq('id', id).select('id'))`
void expectRows(Object? rows) {
  if (rows is! List || rows.isEmpty) throw const WriteDenied();
}

/// يحوّل أي خطأ إلى جملة عربية يفهمها المستخدم — لا نص استثناء خام أبداً.
///
/// وهي أيضاً نقطة المرور التي يصل منها الخطأ إلى [ErrorReporter]: كل
/// تحميل أو حفظ فاشل يمرّ من هنا، فيُسجَّل دون أن يتذكّره كل مستدعٍ.
String userMessageFor(Object error, [StackTrace? stack]) {
  if (error is WriteDenied) {
    return 'لم يُحفظ التعديل: لا تملك صلاحيته، أو أن السجل لم يعد موجوداً.';
  }

  ErrorReporter.reportIfEnabled(error, stack);

  if (error is TimeoutException) {
    return 'استغرق الخادم وقتاً طويلاً. تحقّق من اتصالك ثم أعد المحاولة.';
  }
  if (error is AuthException) {
    return 'انتهت جلستك. سجّل الدخول من جديد.';
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501': // insufficient_privilege
        return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
      case '23505': // unique_violation
        return 'هذا السجل موجود مسبقاً.';
      case '23503': // foreign_key_violation
        return 'لا يمكن تنفيذ ذلك: السجل مرتبط بسجلات أخرى.';
      case '23514': // check_violation
      case '22P02': // invalid_text_representation
        return 'بعض القيم المدخلة غير صالحة. راجعها ثم أعد المحاولة.';
      case 'PGRST301':
      case 'PGRST303':
        return 'انتهت جلستك. سجّل الدخول من جديد.';
    }
    return 'تعذّر إتمام العملية على الخادم. حاول مجدداً بعد قليل.';
  }
  // ClientException (http) وأخطاء الشبكة في المتصفح تصل بأسماء مختلفة
  // حسب المنصّة — نطابقها بالنص بدل استيراد أنواع خاصة بكل منصّة.
  final raw = error.toString().toLowerCase();
  if (raw.contains('failed to fetch') ||
      raw.contains('clientexception') ||
      raw.contains('socketexception') ||
      raw.contains('network')) {
    return 'تعذّر الاتصال بالخادم. تحقّق من اتصالك بالإنترنت.';
  }
  return 'حدث خطأ غير متوقَّع. حاول مجدداً، وإن تكرّر أبلغ الإدارة.';
}
