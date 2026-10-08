import 'package:flutter/material.dart';

import '../brand/tokens.dart';
import '../features/auth/auth_service.dart';

/// ما يراه المسجَّل الذي لا يدخل البوابة: تعذّرت قراءة صلاحيته (شبكة،
/// مهلة) — وهذا ليس «لا صلاحية لك» — أو أن دوره لا يملك أي قسم.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => auth.error != null
      ? ProfileErrorScreen(auth: auth)
      : NoAccessScreen(auth: auth);
}

class ProfileErrorScreen extends StatelessWidget {
  const ProfileErrorScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 46, color: NawahColors.textMuted),
                const SizedBox(height: NawahSpacing.s4),
                Text(
                  auth.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NawahColors.textSoft, height: 1.8),
                ),
                const SizedBox(height: NawahSpacing.s5),
                FilledButton.icon(
                  onPressed: auth.retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
                const SizedBox(height: NawahSpacing.s2),
                TextButton(onPressed: auth.signOut, child: const Text('تسجيل الخروج')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 46,
                color: NawahColors.textMuted,
              ),
              const SizedBox(height: NawahSpacing.s4),
              const Text(
                'لا تملك صلاحية الدخول للوحة',
                style: TextStyle(
                  fontFamily: NawahFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: NawahColors.ink,
                ),
              ),
              const SizedBox(height: NawahSpacing.s2),
              Text(
                'حسابك (${auth.profile?.roleLabel ?? 'غير معروف'}) لا يملك صلاحية '
                'الإدارة. تواصل مع مدير الأكاديمية لترقية حسابك.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: NawahColors.textSoft,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: NawahSpacing.s5),
              OutlinedButton.icon(
                onPressed: auth.signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
