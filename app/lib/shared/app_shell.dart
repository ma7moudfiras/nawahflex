import 'package:flutter/material.dart';

import '../brand/logo.dart';
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
    this.onChangePassword,
  });

  final String displayName;
  final String roleLabel;
  final String initial;
  final VoidCallback onSignOut;

  /// يفتح نموذج تغيير كلمة المرور؛ فارغ = لا يظهر الخيار (المعاينة والاختبار).
  final void Function(BuildContext context)? onChangePassword;
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

    // NavigationRail يشترط عنصرين على الأقل — المدرّب له قسم واحد فقط
    // (اللقاءات)، فيُعرض بلا تنقّل بدل أن ينهار التطبيق.
    if (items.length < 2) {
      return Scaffold(
        body: Column(
          children: [
            _TopBar(
              title: title ?? items.first.label,
              actions: [...?actions, _AccountButton(account: account, extended: false)],
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 208,
            selectedIndex: index,
            onDestinationSelected: onSelect,
            backgroundColor: NawahColors.ink,
            indicatorColor: NawahColors.inkLine,
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
              color: NawahColors.invertSoft,
              fontFamily: NawahFonts.body,
            ),
            unselectedIconTheme: const IconThemeData(color: NawahColors.invertSoft),
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
  //
  // الشريط السفلي يتّسع لأربعة عناصر بأسماء مقروءة. الأقسام المثبَّتة
  // (NavItem.pinned) تظهر فيه مباشرة، والباقي خلف «المزيد» في لوح سفلي —
  // بدل تسعة أيقونات متلاصقة تنكسر أسماؤها على سطرين.
  static const _maxPinned = 4;

  Widget _narrow(BuildContext context) {
    final appBar = AppBar(
      titleSpacing: NawahSpacing.s4,
      title: Row(
        children: [
          const NawahLogo(height: 24, color: NawahColors.ink),
          const SizedBox(width: NawahSpacing.s3),
          Flexible(
            child: Text(title ?? items[index].label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        ...?actions,
        _AccountButton(account: account, extended: false),
        const SizedBox(width: NawahSpacing.s2),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: NawahColors.border),
      ),
    );

    if (items.length < 2) {
      return Scaffold(appBar: appBar, body: child);
    }

    // الفهارس الأصلية للعناصر الظاهرة في الشريط، وللعناصر خلف «المزيد».
    final all = List<int>.generate(items.length, (i) => i);
    var pinned = all.where((i) => items[i].pinned).take(_maxPinned).toList();
    if (pinned.isEmpty) pinned = all.take(_maxPinned).toList();
    final overflow = all.where((i) => !pinned.contains(i)).toList();
    // لا معنى لـ«المزيد» يحوي عنصراً واحداً — يظهر هو نفسه مكانه.
    if (overflow.length == 1) {
      pinned = [...pinned, overflow.single];
      overflow.clear();
    }

    final inOverflow = overflow.contains(index);
    final overflowBadge =
        overflow.fold<int>(0, (sum, i) => sum + items[i].badgeCount);

    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: NawahColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: inOverflow ? pinned.length : pinned.indexOf(index),
          onDestinationSelected: (i) {
            if (i < pinned.length) {
              onSelect(pinned[i]);
            } else {
              _openMore(context, overflow);
            }
          },
          destinations: [
            for (final i in pinned)
              NavigationDestination(
                icon: _Badged(count: items[i].badgeCount, child: Icon(items[i].icon)),
                selectedIcon: _Badged(
                  count: items[i].badgeCount,
                  child: Icon(items[i].selectedIcon),
                ),
                label: items[i].label,
              ),
            if (overflow.isNotEmpty)
              NavigationDestination(
                icon: _Badged(
                  count: overflowBadge,
                  child: Icon(inOverflow ? items[index].icon : Icons.menu),
                ),
                selectedIcon: _Badged(
                  count: overflowBadge,
                  child: Icon(items[index].selectedIcon),
                ),
                // حين يكون القسم المفتوح من «المزيد» يظهر اسمه هنا، فيعرف
                // المستخدم أين هو دون النظر إلى العنوان.
                label: inOverflow ? items[index].label : 'المزيد',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMore(BuildContext context, List<int> overflow) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: NawahSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in overflow)
                ListTile(
                  leading: _Badged(
                    count: items[i].badgeCount,
                    child: Icon(
                      i == index ? items[i].selectedIcon : items[i].icon,
                      color: NawahColors.ink,
                    ),
                  ),
                  title: Text(
                    items[i].label,
                    style: TextStyle(
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                      color: NawahColors.ink,
                    ),
                  ),
                  selected: i == index,
                  selectedTileColor: NawahColors.inkTint,
                  minTileHeight: 52,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    onSelect(i);
                  },
                ),
              const Divider(height: NawahSpacing.s5),
              ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: NawahColors.ink,
                  child: Text(
                    account.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(account.displayName),
                subtitle: Text(account.roleLabel),
              ),
              if (account.onChangePassword != null)
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: NawahColors.ink),
                  title: const Text('تغيير كلمة المرور'),
                  minTileHeight: 52,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    account.onChangePassword!(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout, color: NawahColors.err),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: NawahColors.err, fontWeight: FontWeight.w600),
                ),
                minTileHeight: 52,
                onTap: () {
                  Navigator.of(sheet).pop();
                  account.onSignOut();
                },
              ),
            ],
          ),
        ),
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
      textColor: NawahColors.onAccent,
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
          const NawahLogo(height: 34, color: NawahColors.textInvert),
          if (extended) ...[
            const SizedBox(width: NawahSpacing.s3),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أكاديمية نواة',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: NawahFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    )),
                Text('لوحة الإدارة',
                    style: TextStyle(color: NawahColors.invertSoft, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
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
        if (v == 'password') account.onChangePassword?.call(context);
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
        if (account.onChangePassword != null)
          const PopupMenuItem(
            value: 'password',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_reset, size: 20),
              title: Text('تغيير كلمة المرور'),
            ),
          ),
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
