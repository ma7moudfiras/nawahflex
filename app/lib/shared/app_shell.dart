import 'package:flutter/material.dart';

import '../brand/tokens.dart';
import 'adaptive.dart';
import 'nav_item.dart';

/// ما يحتاجه الهيكل من الحساب — لا أكثر.
///
/// تمرير AuthService كاملاً كان يربط الهيكل بـ Supabase ويمنع اختباره
/// دون شبكة. هذه الحزمة الصغيرة تفكّ الارتباط وتجعل الهيكل قابلاً للاختبار.
class AccountInfo {
  const AccountInfo({
    required this.displayName,
    required this.roleLabel,
    required this.initial,
    required this.onSignOut,
  });

  final String displayName;
  final String roleLabel;
  final String initial;
  final VoidCallback onSignOut;
}

/// الهيكل الذي يلفّ كل شاشات اللوحة.
///
/// مكتب/لوحي → NavigationRail جانبي دائم الظهور.
/// جوّال     → NavigationBar سفلي يصله الإبهام.
/// المحتوى نفسه لا يتغيّر — الشاشات لا تعرف أي وضع تعمل فيه.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.account,
    required this.child,
    this.title,
    this.actions,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final AccountInfo account;
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return context.isWide ? _wide(context) : _narrow(context);
  }

  // ---------- مكتب ولوحي ----------
  Widget _wide(BuildContext context) {
    final extended = context.isDesktop;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 208,
            selectedIndex: index,
            onDestinationSelected: onSelect,
            backgroundColor: NawahColors.ink,
            indicatorColor: NawahColors.primary.withValues(alpha: .22),
            leading: _RailHeader(extended: extended),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: NawahSpacing.s5),
                  child: _AccountButton(account: account, extended: extended),
                ),
              ),
            ),
            destinations: [
              for (final it in items)
                NavigationRailDestination(
                  icon: _Badged(count: it.badgeCount, child: Icon(it.icon)),
                  selectedIcon: _Badged(
                    count: it.badgeCount,
                    child: Icon(it.selectedIcon, color: Colors.white),
                  ),
                  label: Text(it.label),
                ),
            ],
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: NawahFonts.body,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Color(0xFF93A2C2),
              fontFamily: NawahFonts.body,
            ),
            unselectedIconTheme: const IconThemeData(color: Color(0xFF93A2C2)),
            selectedIconTheme: const IconThemeData(color: Colors.white),
          ),
          const VerticalDivider(width: 1, color: NawahColors.border),
          Expanded(
            child: Column(
              children: [
                if (title != null) _TopBar(title: title!, actions: actions),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- جوّال ----------
  Widget _narrow(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? items[index].label),
        actions: [...?actions, _AccountButton(account: account, extended: false)],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        destinations: [
          for (final it in items)
            NavigationDestination(
              icon: _Badged(count: it.badgeCount, child: Icon(it.icon)),
              selectedIcon: _Badged(count: it.badgeCount, child: Icon(it.selectedIcon)),
              label: it.label,
            ),
        ],
      ),
    );
  }
}

/// شارة العدد فوق الأيقونة — تُظهر الرسائل الجديدة دون فتح الشاشة.
class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge.count(
      count: count,
      backgroundColor: NawahColors.accent,
      textColor: const Color(0xFF3D2600),
      child: child,
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NawahSpacing.s5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Nucleus(size: 34),
          if (extended) ...[
            const SizedBox(width: NawahSpacing.s3),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نواة فليكس',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: NawahFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    )),
                Text('لوحة الإدارة',
                    style: TextStyle(color: Color(0xFF6B7A9C), fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// شعار النواة — نفس فكرة شعار الموقع، مرسوم بـ Flutter لا صورة.
class _Nucleus extends StatelessWidget {
  const _Nucleus({this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: -0.5, child: _ring(NawahColors.cyan)),
          Transform.rotate(angle: 0.56, child: _ring(NawahColors.violet)),
          Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF60A5FA), NawahColors.primary],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(Color c) => Container(
        width: size,
        height: size * 0.42,
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.4),
          borderRadius: BorderRadius.all(Radius.elliptical(size, size * 0.42)),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: NawahSpacing.s6),
      decoration: const BoxDecoration(
        color: NawahColors.card,
        border: Border(bottom: BorderSide(color: NawahColors.border)),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                fontFamily: NawahFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: NawahColors.ink,
              )),
          const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.account, required this.extended});
  final AccountInfo account;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: NawahColors.primary,
      child: Text(
        account.initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      onSelected: (v) {
        if (v == 'signout') account.onSignOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(account.displayName),
            subtitle: Text(account.roleLabel),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, size: 20),
            title: Text('تسجيل الخروج'),
          ),
        ),
      ],
      child: extended
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: NawahSpacing.s3),
                Flexible(
                  child: Text(
                    account.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            )
          : Padding(padding: const EdgeInsets.all(8), child: avatar),
    );
  }
}
