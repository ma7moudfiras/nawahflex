import 'package:flutter/material.dart';

import 'adaptive.dart';

/// يفتح نموذجاً بالشكل المناسب للشاشة: حوار في الوسط على المكتب واللوحي،
/// ولوح سفلي على الجوّال يصله الإبهام.
///
/// مكان واحد بدل تكرار نفس الشرط في كل شاشة. على الجوّال:
/// - useSafeArea: لا يصعد اللوح تحت شريط الحالة وساعة الهاتف.
/// - isScrollControlled: النموذج الطويل يأخذ ارتفاعه، ويتمرّر داخله.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 480,
}) {
  if (context.isWide) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    // فوق الهيكل كله لا داخل القسم: الأقسام داخل ShellRoute لها موجّهها،
    // ولوح فيه كان يترك الشريط السفلي ظاهراً وقابلاً للنقر أثناء النموذج.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}
