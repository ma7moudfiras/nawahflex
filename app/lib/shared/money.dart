import '../core/config.dart';

/// تنسيق مبلغ مالي بعملة واحدة موحَّدة — نقطة تحرير واحدة عند تغيير
/// العملة (أكاديمية أخرى بعملة مختلفة، مثلاً)، بدل رمز مكرَّر بكل شاشة.
String formatMoney(num amount) {
  final n = amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  return '$n ${AppConfig.currencySymbol}';
}
