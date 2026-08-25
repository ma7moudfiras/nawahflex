import 'package:flutter/material.dart';

/// عنصر في التنقّل — يُعرض في الشريط الجانبي على المكتب
/// وفي الشريط السفلي على الجوّال، من نفس التعريف.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;

  NavItem withBadge(int count) => NavItem(
        label: label,
        icon: icon,
        selectedIcon: selectedIcon,
        badgeCount: count,
      );
}
