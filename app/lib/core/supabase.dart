import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// نقطة الوصول الوحيدة إلى Supabase في التطبيق.
class Db {
  Db._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  static Session? get session => auth.currentSession;
  static User? get user => auth.currentUser;
  static bool get isSignedIn => session != null;

  static Future<void> init() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // publishableKey هو البديل الحديث لـ anonKey المهجورة
      publishableKey: AppConfig.supabaseKey,
    );
  }
}
