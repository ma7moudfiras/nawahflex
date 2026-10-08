/// حال إشعارات الجوال على هذا الجهاز — تحدّد ما يعرضه لوح الإشعارات.
enum PushState {
  /// المتصفح لا يدعم Web Push.
  unsupported,

  /// آيفون من سفاري: يلزم «إضافة إلى الشاشة الرئيسية» ثم الفتح من الأيقونة (iOS 16.4+).
  needsInstall,

  /// لم يُسأل بعد — يظهر زر «فعّل».
  notAsked,

  /// رفضها المستخدم — تُفعَّل من إعدادات المتصفح وحدها.
  denied,

  /// مُفعَّلة.
  granted,
}

/// القرار من حقائق الجهاز — دالة خالصة كي تُختبر دون متصفح.
PushState decidePushState({
  required bool hasNotificationApi,
  required bool hasPushManager,
  required bool isIos,
  required bool standalone,
  required String permission,
}) {
  if (!hasNotificationApi || !hasPushManager) {
    return isIos && !standalone ? PushState.needsInstall : PushState.unsupported;
  }
  return switch (permission) {
    'granted' => PushState.granted,
    'denied' => PushState.denied,
    _ => PushState.notAsked,
  };
}
