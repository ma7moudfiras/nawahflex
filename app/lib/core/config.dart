/// إعدادات الاتصال بـ Supabase.
///
/// نفس المشروع الذي يستخدمه الموقع التعريفي — قاعدة واحدة لا اثنتان.
/// المفتاح أدناه هو المفتاح العلني (publishable) وهو مصمَّم ليكون مكشوفاً؛
/// الحماية الحقيقية من سياسات RLS. ⛔ لا يقترب service_role من هنا أبداً.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = 'https://zhpnqtwegulqhalfvvoj.supabase.co';
  static const supabaseKey = 'sb_publishable_TqhKQEe5deDJ-es_wiGHLA_dAVW1LuC';

  /// عرض الشاشة الذي عنده ينتقل التخطيط من «جوّال» إلى «مكتب».
  ///
  /// الإدارة تعمل معظم شغلها على المكتب، والأهالي على الجوّال — فالتطبيق
  /// يخدم الاثنين بنفس الكود ويبدّل الهيكل عند هذه الحدود.
  static const double breakpointTablet = 720;
  static const double breakpointDesktop = 1100;
}
