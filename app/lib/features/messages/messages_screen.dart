import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import 'message.dart';
import 'messages_repository.dart';

/// شاشة الرسائل الواردة.
///
/// مكتب  → قائمة يسار + تفاصيل يمين في آنٍ واحد (master/detail).
/// جوّال → قائمة فقط، والتفاصيل تُفتح كصفحة منفصلة.
/// نفس الودجات في الحالتين — يتغيّر التركيب لا المحتوى.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.onCountsChanged});
  final ValueChanged<Map<String, int>> onCountsChanged;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _repo = const MessagesRepository();
  List<Message> _items = [];
  Message? _selected;
  String _filter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetch(status: _filter);
      final counts = await _repo.counts();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        // إبقاء المحدَّد إن كان ما زال ضمن النتائج
        if (_selected != null && !items.any((m) => m.id == _selected!.id)) {
          _selected = null;
        }
      });
      widget.onCountsChanged(counts);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الرسائل. تحقّق من اتصالك ثم أعد المحاولة.';
      });
    }
  }

  Future<void> _setStatus(Message m, String status) async {
    try {
      await _repo.setStatus(m.id, status);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم التحديث إلى «${Message.statusLabels[status]}»')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر التحديث — تأكّد من صلاحيتك.')),
        );
      }
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _Empty(
        icon: Icons.wifi_off,
        title: 'تعذّر التحميل',
        subtitle: _error!,
        action: FilledButton.tonal(onPressed: _load, child: const Text('إعادة المحاولة')),
      );
    }

    final list = Column(
      children: [
        _FilterBar(current: _filter, onChange: (f) {
          setState(() => _filter = f);
          _load();
        }),
        Expanded(
          child: _items.isEmpty
              ? const _Empty(
                  icon: Icons.inbox_outlined,
                  title: 'لا رسائل هنا',
                  subtitle: 'ستظهر رسائل نموذج التواصل في الموقع فور وصولها.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(NawahSpacing.s4),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: NawahSpacing.s2),
                    itemBuilder: (_, i) {
                      final m = _items[i];
                      return _MessageTile(
                        message: m,
                        selected: context.isWide && _selected?.id == m.id,
                        onTap: () {
                          if (context.isWide) {
                            setState(() => _selected = m);
                          } else {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(m.name)),
                                body: _Detail(
                                  message: m,
                                  onStatus: (s) => _setStatus(m, s),
                                  onOpen: _open,
                                ),
                              ),
                            ));
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );

    if (!context.isWide) return list;

    // مكتب ولوحي: عمودان
    return Row(
      children: [
        SizedBox(width: adaptive(context, mobile: 320.0, tablet: 320.0, desktop: 400.0), child: list),
        const VerticalDivider(width: 1, color: NawahColors.border),
        Expanded(
          child: _selected == null
              ? const _Empty(
                  icon: Icons.touch_app_outlined,
                  title: 'اختر رسالة',
                  subtitle: 'اضغط على أي رسالة من القائمة لعرض تفاصيلها والردّ عليها.',
                )
              : _Detail(
                  message: _selected!,
                  onStatus: (s) => _setStatus(_selected!, s),
                  onOpen: _open,
                ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChange});
  final String current;
  final ValueChanged<String> onChange;

  static const _filters = <String, String>{
    'all': 'الكل',
    'new': 'جديدة',
    'in_progress': 'قيد المتابعة',
    'done': 'مكتملة',
    'spam': 'مزعجة',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          NawahSpacing.s4, NawahSpacing.s4, NawahSpacing.s4, 0),
      child: Row(
        children: [
          for (final e in _filters.entries)
            Padding(
              padding: const EdgeInsets.only(left: NawahSpacing.s2),
              child: ChoiceChip(
                label: Text(e.value),
                selected: current == e.key,
                onSelected: (_) => onChange(e.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.selected, required this.onTap});
  final Message message;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NawahColors.primarySoft : NawahColors.card,
      borderRadius: BorderRadius.circular(NawahRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NawahRadius.md),
        child: Container(
          padding: const EdgeInsets.all(NawahSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NawahRadius.md),
            border: Border.all(
              color: selected ? NawahColors.primary : NawahColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (message.isNew)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      decoration: const BoxDecoration(
                        color: NawahColors.accent, shape: BoxShape.circle),
                    ),
                  Expanded(
                    child: Text(message.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: NawahColors.ink,
                        )),
                  ),
                  Text(_ago(message.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: NawahColors.textMuted)),
                ],
              ),
              const SizedBox(height: 4),
              Text(message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: NawahColors.textSoft, height: 1.5)),
              if (message.interest != null) ...[
                const SizedBox(height: NawahSpacing.s2),
                _Chip(text: message.interest!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} ي';
    return '${d.year}/${d.month}/${d.day}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: NawahColors.bgAlt,
          borderRadius: BorderRadius.circular(NawahRadius.full),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: NawahColors.textSoft)),
      );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.message, required this.onStatus, required this.onOpen});
  final Message message;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(adaptive(context, mobile: 16.0, desktop: 32.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.name,
              style: const TextStyle(
                fontFamily: NawahFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: NawahColors.ink,
              )),
          const SizedBox(height: 4),
          Text('وردت ${message.createdAt.year}/${message.createdAt.month}/${message.createdAt.day}'
              ' — ${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: NawahColors.textMuted, fontSize: 12)),

          const SizedBox(height: NawahSpacing.s5),
          // أزرار التواصل — الردّ أهم إجراء في هذه الشاشة
          Wrap(
            spacing: NawahSpacing.s2,
            runSpacing: NawahSpacing.s2,
            children: [
              FilledButton.icon(
                onPressed: () => onOpen(message.whatsappUrl),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('واتساب'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpen(message.telUrl),
                icon: const Icon(Icons.phone, size: 18),
                label: Text(message.phone, textDirection: TextDirection.ltr),
              ),
              if (message.email != null && message.email!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => onOpen('mailto:${message.email}'),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: Text(message.email!, textDirection: TextDirection.ltr),
                ),
            ],
          ),

          const SizedBox(height: NawahSpacing.s5),
          if (message.interest != null)
            _Field(label: 'البرنامج المهتم به', value: message.interest!),
          _Field(label: 'الرسالة', value: message.body, multiline: true),

          const SizedBox(height: NawahSpacing.s5),
          const Text('الحالة',
              style: TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink)),
          const SizedBox(height: NawahSpacing.s2),
          Wrap(
            spacing: NawahSpacing.s2,
            children: [
              for (final e in Message.statusLabels.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: message.status == e.key,
                  onSelected: (_) => onStatus(e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.multiline = false});
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: NawahSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NawahColors.textMuted)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(multiline ? NawahSpacing.s4 : 0),
              decoration: multiline
                  ? BoxDecoration(
                      color: NawahColors.bgAlt,
                      borderRadius: BorderRadius.circular(NawahRadius.sm),
                    )
                  : null,
              child: Text(value,
                  style: const TextStyle(
                      color: NawahColors.text, height: 1.8, fontSize: 14)),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: NawahColors.textMuted),
              const SizedBox(height: NawahSpacing.s4),
              Text(title,
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NawahColors.textSoft, height: 1.7)),
              if (action != null) ...[
                const SizedBox(height: NawahSpacing.s5),
                action!,
              ],
            ],
          ),
        ),
      );
}
