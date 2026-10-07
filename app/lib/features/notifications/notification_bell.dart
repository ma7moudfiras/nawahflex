import 'dart:async';

import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/push.dart';
import '../../shared/form_error.dart';
import '../../shared/sheets.dart';
import 'app_notification.dart';
import 'notifications_repository.dart';

const _repo = NotificationsRepository();

/// جرس الإشعارات في رأس البوابة (وليّ الأمر والطالب): عدد غير المقروء،
/// والنقر يفتح القائمة. يتحدّث كل دقيقتين وعند إغلاق القائمة.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.isParent, required this.isStudent, required this.onOpen});
  final bool isParent;
  final bool isStudent;

  /// ينتقل إلى صفحة داخل البوابة (`context.go` من الهيكل).
  final void Function(String path) onOpen;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final n = await _repo.unreadCount();
      if (mounted && n != _unread) setState(() => _unread = n);
    } catch (_) {
      // عدّاد فقط — انقطاع عابر لا يستحق رسالة؛ المحاولة التالية بعد دقيقتين.
    }
  }

  Future<void> _open() async {
    final path = await showAdaptiveSheet<String>(
      context,
      builder: (_) => _NotificationsSheet(isParent: widget.isParent, isStudent: widget.isStudent),
    );
    await _refresh();
    if (path != null) widget.onOpen(path);
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_unread > 0 ? Icons.notifications : Icons.notifications_outlined);
    return IconButton(
      tooltip: _unread > 0 ? 'الإشعارات ($_unread جديدة)' : 'الإشعارات',
      onPressed: _open,
      icon: _unread > 0
          ? Badge.count(
              count: _unread,
              backgroundColor: NawahColors.accent,
              textColor: NawahColors.onAccent,
              child: icon,
            )
          : icon,
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.isParent, required this.isStudent});
  final bool isParent;
  final bool isStudent;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<AppNotification>? _items;
  String? _error;
  PushState _push = currentPushState();
  bool _pushBusy = false;
  String? _pushError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.fetchRecent();
      if (mounted) setState(() => _items = items);
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    }
  }

  Future<void> _tap(AppNotification n) async {
    if (!n.isRead) {
      try {
        await _repo.markRead(n.id);
      } catch (_) {
        // الانتقال أهمّ من علامة القراءة؛ تُعلَّم في المرة القادمة.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(n.targetPath(isParent: widget.isParent, isStudent: widget.isStudent));
  }

  Future<void> _markAll() async {
    try {
      await _repo.markAllRead();
      await _load();
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    }
  }

  Future<void> _enablePush() async {
    setState(() {
      _pushBusy = true;
      _pushError = null;
    });
    try {
      final s = await _repo.enableDevicePush();
      if (mounted) setState(() => _push = s);
    } catch (e, st) {
      if (mounted) setState(() => _pushError = userMessageFor(e, st));
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasUnread = items?.any((n) => !n.isRead) ?? false;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(NawahSpacing.s5, NawahSpacing.s4, NawahSpacing.s3, NawahSpacing.s2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الإشعارات',
                      style: TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
                    ),
                  ),
                  if (hasUnread) TextButton(onPressed: _markAll, child: const Text('تعليم الكل مقروءاً')),
                ],
              ),
            ),
            _PushBanner(state: _push, busy: _pushBusy, error: _pushError, onEnable: _enablePush),
            Flexible(
              child: switch ((items, _error)) {
                (_, final String e) => Padding(
                    padding: const EdgeInsets.all(NawahSpacing.s5),
                    child: FormErrorBanner(message: e),
                  ),
                (null, _) => const Padding(
                    padding: EdgeInsets.all(NawahSpacing.s6),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                (final List<AppNotification> list, _) when list.isEmpty => const Padding(
                    padding: EdgeInsets.all(NawahSpacing.s6),
                    child: Text(
                      'لا إشعارات بعد. ستصلك هنا الشارات والشهادات وملاحظات المدرّب.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NawahColors.textMuted, height: 1.7),
                    ),
                  ),
                (final List<AppNotification> list, _) => ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: NawahSpacing.s4),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: NawahColors.borderSoft),
                    itemBuilder: (_, i) => _Item(n: list[i], onTap: () => _tap(list[i])),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: n.isRead ? null : NawahColors.accentSoft.withValues(alpha: 0.45),
      leading: Icon(n.icon, color: n.isRead ? NawahColors.textMuted : NawahColors.ink),
      title: Text(
        n.title,
        style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700, color: NawahColors.ink),
      ),
      subtitle: Text(
        [if ((n.body ?? '').isNotEmpty) n.body!, relativeTime(n.createdAt)].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: NawahColors.textSoft, height: 1.6),
      ),
      trailing: n.isRead
          ? null
          : Container(width: 8, height: 8, decoration: const BoxDecoration(color: NawahColors.accent, shape: BoxShape.circle)),
    );
  }
}

/// سطر إشعارات الجوال أعلى القائمة — حسب حال الجهاز.
class _PushBanner extends StatelessWidget {
  const _PushBanner({required this.state, required this.busy, required this.error, required this.onEnable});
  final PushState state;
  final bool busy;
  final String? error;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final (String text, bool action) = switch (state) {
      PushState.notAsked => ('فعّل إشعارات الجوال لتصلك حتى والبوابة مغلقة.', true),
      PushState.needsInstall => (
          'على آيفون: من سفاري اضغط «مشاركة» ثم «إضافة إلى الشاشة الرئيسية»، وافتح البوابة من أيقونتها — عندها تُفعَّل الإشعارات.',
          false
        ),
      PushState.denied => ('إشعارات الجوال محجوبة لهذا الموقع. فعّلها من إعدادات المتصفح.', false),
      PushState.granted || PushState.unsupported => ('', false),
    };
    if (text.isEmpty && error == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(NawahSpacing.s4, 0, NawahSpacing.s4, NawahSpacing.s3),
      padding: const EdgeInsets.all(NawahSpacing.s3),
      decoration: BoxDecoration(color: NawahColors.paper, borderRadius: BorderRadius.circular(NawahRadius.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (text.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.phone_iphone, size: 20, color: NawahColors.ink),
                const SizedBox(width: NawahSpacing.s2),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.6, color: NawahColors.text))),
                if (action) ...[
                  const SizedBox(width: NawahSpacing.s2),
                  FilledButton(
                    onPressed: busy ? null : onEnable,
                    child: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('فعّل'),
                  ),
                ],
              ],
            ),
          if (error != null) ...[const SizedBox(height: NawahSpacing.s2), FormErrorBanner(message: error)],
        ],
      ),
    );
  }
}
