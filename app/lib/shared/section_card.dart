import 'package:flutter/material.dart';

import '../brand/tokens.dart';

/// بطاقة قسم في صفحات الملفات: عنوان، وإجراء اختياري، ومحتوى.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.action,
  });

  final String title;
  final IconData? icon;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NawahSpacing.s4),
      decoration: BoxDecoration(
        color: NawahColors.card,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        border: Border.all(color: NawahColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: NawahColors.ink),
                const SizedBox(width: NawahSpacing.s2),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: NawahColors.ink,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: NawahSpacing.s3),
          child,
        ],
      ),
    );
  }
}

/// رقم واحد بعنوانه — شريط إحصاءات الملف.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NawahSpacing.s3, vertical: NawahSpacing.s3),
      decoration: BoxDecoration(
        color: NawahColors.card,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        border: Border.all(color: NawahColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: NawahColors.textMuted),
                const SizedBox(width: NawahSpacing.s1),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: NawahColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: NawahSpacing.s1),
          Text(
            value,
            style: const TextStyle(
              fontFamily: NawahFonts.display,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: NawahColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// كتلة رمادية مكان محتوى لم يصل بعد — شكل الصفحة يظهر فوراً بلا قفز.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = NawahRadius.sm});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: NawahColors.paperDeep,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
