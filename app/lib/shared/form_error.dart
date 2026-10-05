import 'package:flutter/material.dart';

import '../brand/tokens.dart';

/// خطأ الحفظ داخل النموذج نفسه، فوق زر الحفظ مباشرة.
///
/// لماذا لا SnackBar؟ النموذج على الجوّال لوح سفلي، والـ SnackBar يُرسم في
/// الـ Scaffold الذي تحته — فيختفي خلف اللوح ولا يرى المستخدم أن الحفظ فشل.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: NawahSpacing.s3),
      padding: const EdgeInsets.all(NawahSpacing.s3),
      decoration: BoxDecoration(
        color: NawahColors.errSoft,
        borderRadius: BorderRadius.circular(NawahRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: NawahColors.err),
          const SizedBox(width: NawahSpacing.s2),
          Expanded(
            child: Text(
              m,
              style: const TextStyle(color: NawahColors.err, height: 1.6, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
