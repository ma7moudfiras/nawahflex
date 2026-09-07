/// سطر تدقيق موحَّد: "بواسطة فلان — يوم/شهر/سنة الساعة س:د" — نقطة تحرير
/// واحدة تُستعمل أينما احتجنا نُجيب "مين وإمتى" (دفعة، خصم إخوة، سعر
/// ساعة، تسديد مستحقات مدرّب...).
String auditLine(String? byName, DateTime at) {
  final who = byName != null && byName.trim().isNotEmpty ? byName : 'الإدارة';
  final time =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  return 'بواسطة $who — ${at.year}/${at.month}/${at.day} $time';
}
