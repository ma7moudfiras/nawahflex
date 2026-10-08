import 'package:flutter/material.dart';

import '../brand/tokens.dart';
import 'adaptive.dart';

/// بطاقات البرامج والمدرّبين والأفواج.
///
/// على الجوّال: قائمة، كل بطاقة بطول محتواها — الشبكة بارتفاع ثابت كانت
/// تترك نصف كل بطاقة فارغاً. على الأعرض: شبكة بأعمدة وارتفاع موحَّد.
/// المسافة السفلية تُبقي آخر بطاقة ظاهرة فوق زر الإضافة العائم.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.extent,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// ارتفاع البطاقة في الشبكة (المكتب واللوحي فقط).
  final double extent;
  final int tabletColumns;
  final int desktopColumns;

  static const _fabClearance = 96.0;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(
      NawahSpacing.s4,
      NawahSpacing.s4,
      NawahSpacing.s4,
      _fabClearance,
    );
    if (context.isMobile) {
      return ListView.separated(
        padding: pad,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: NawahSpacing.s3),
        itemBuilder: itemBuilder,
      );
    }
    return GridView.builder(
      padding: pad,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: adaptive(
          context,
          mobile: 1,
          tablet: tabletColumns,
          desktop: desktopColumns,
        ),
        mainAxisSpacing: NawahSpacing.s3,
        crossAxisSpacing: NawahSpacing.s3,
        mainAxisExtent: extent,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
