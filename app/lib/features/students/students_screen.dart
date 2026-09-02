import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../brand/tokens.dart';
import '../../shared/adaptive.dart';
import 'student.dart';
import 'student_form.dart';
import 'students_repository.dart';

/// شاشة الطلاب — نفس نمط شاشة الرسائل: قائمة+تفاصيل على العريض،
/// قائمة فقط على الجوّال مع فتح التفاصيل كصفحة منفصلة.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _repo = const StudentsRepository();
  final _search = TextEditingController();
  List<Student> _items = [];
  Student? _selected;
  bool _activeOnly = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _repo.fetch(query: _search.text, activeOnly: _activeOnly);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        if (_selected != null && !items.any((s) => s.id == _selected!.id)) _selected = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذّر تحميل الطلاب. تحقّق من اتصالك ثم أعد المحاولة.'; });
    }
  }

  Future<void> _openForm({Student? existing}) async {
    final isWide = context.isWide;
    Future<void> onSubmit(Student s) async {
      if (existing == null) {
        await _repo.create(s);
      } else {
        await _repo.update(existing.id, s);
      }
      await _load();
    }

    if (isWide) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: StudentForm(initial: existing, onSubmit: onSubmit),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StudentForm(initial: existing, onSubmit: onSubmit),
      );
    }
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());

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
        Padding(
          padding: const EdgeInsets.fromLTRB(NawahSpacing.s4, NawahSpacing.s4, NawahSpacing.s4, 0),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward, size: 18), onPressed: _load),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(NawahSpacing.s4, NawahSpacing.s3, NawahSpacing.s4, 0),
          child: Row(
            children: [
              FilterChip(
                label: const Text('النشطون فقط'),
                selected: _activeOnly,
                onSelected: (v) { setState(() => _activeOnly = v); _load(); },
              ),
              const Spacer(),
              Text('${_items.length} طالب', style: const TextStyle(color: NawahColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const _Empty(
                  icon: Icons.groups_outlined,
                  title: 'لا يوجد طلاب بعد',
                  subtitle: 'اضغط زر الإضافة لتسجيل أول طالب.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(NawahSpacing.s4),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: NawahSpacing.s2),
                    itemBuilder: (_, i) {
                      final s = _items[i];
                      return _StudentTile(
                        student: s,
                        selected: context.isWide && _selected?.id == s.id,
                        onTap: () {
                          if (context.isWide) {
                            setState(() => _selected = s);
                          } else {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(s.fullName), actions: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _openForm(existing: s),
                                  ),
                                ]),
                                body: _Detail(student: s, onOpen: _open),
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

    final body = !context.isWide
        ? list
        : Row(
            children: [
              SizedBox(width: adaptive(context, mobile: 320.0, tablet: 320.0, desktop: 380.0), child: list),
              const VerticalDivider(width: 1, color: NawahColors.border),
              Expanded(
                child: _selected == null
                    ? const _Empty(
                        icon: Icons.touch_app_outlined,
                        title: 'اختر طالباً',
                        subtitle: 'اضغط على أي طالب من القائمة لعرض بياناته.',
                      )
                    : _Detail(student: _selected!, onOpen: _open, onEdit: () => _openForm(existing: _selected)),
              ),
            ],
          );

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'إضافة طالب',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.selected, required this.onTap});
  final Student student;
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
          padding: const EdgeInsets.all(NawahSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NawahRadius.md),
            border: Border.all(color: selected ? NawahColors.primary : NawahColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: student.isActive ? NawahColors.primary : NawahColors.textMuted,
                child: Text(student.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: NawahSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink)),
                    if (student.guardianName != null && student.guardianName!.isNotEmpty)
                      Text('ولي الأمر: ${student.guardianName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: NawahColors.textMuted)),
                  ],
                ),
              ),
              if (student.age != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: NawahColors.bgAlt, borderRadius: BorderRadius.circular(NawahRadius.full)),
                  child: Text('${student.age}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.student, required this.onOpen, this.onEdit});
  final Student student;
  final ValueChanged<String> onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(adaptive(context, mobile: 16.0, desktop: 32.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(student.fullName,
                    style: const TextStyle(
                      fontFamily: NawahFonts.display, fontWeight: FontWeight.w800,
                      fontSize: 22, color: NawahColors.ink,
                    )),
              ),
              if (onEdit != null)
                OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('تعديل')),
            ],
          ),
          if (student.age != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${student.age} سنة${student.gender == 'm' ? ' · ذكر' : student.gender == 'f' ? ' · أنثى' : ''}',
                  style: const TextStyle(color: NawahColors.textMuted, fontSize: 13)),
            ),

          const SizedBox(height: NawahSpacing.s5),
          if (student.guardianName != null && student.guardianName!.isNotEmpty) ...[
            const Text('ولي الأمر', style: TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink)),
            const SizedBox(height: NawahSpacing.s2),
            Text(student.guardianName!, style: const TextStyle(color: NawahColors.textSoft)),
            const SizedBox(height: NawahSpacing.s4),
            Wrap(
              spacing: NawahSpacing.s2,
              children: [
                if (student.guardianPhone != null && student.guardianPhone!.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () => onOpen(student.whatsappUrl),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('واتساب'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onOpen('tel:${student.guardianPhone}'),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(student.guardianPhone!, textDirection: TextDirection.ltr),
                  ),
                ],
                if (student.guardianEmail != null && student.guardianEmail!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onOpen('mailto:${student.guardianEmail}'),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(student.guardianEmail!, textDirection: TextDirection.ltr),
                  ),
              ],
            ),
          ],

          if (student.notes != null && student.notes!.isNotEmpty) ...[
            const SizedBox(height: NawahSpacing.s5),
            const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.w700, color: NawahColors.ink)),
            const SizedBox(height: NawahSpacing.s2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(NawahSpacing.s4),
              decoration: BoxDecoration(color: NawahColors.bgAlt, borderRadius: BorderRadius.circular(NawahRadius.sm)),
              child: Text(student.notes!, style: const TextStyle(color: NawahColors.text, height: 1.8)),
            ),
          ],
        ],
      ),
    );
  }
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
                    fontFamily: NawahFonts.display, fontWeight: FontWeight.w700,
                    fontSize: 17, color: NawahColors.ink,
                  )),
              const SizedBox(height: NawahSpacing.s2),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: NawahColors.textSoft, height: 1.7)),
              if (action != null) ...[const SizedBox(height: NawahSpacing.s5), action!],
            ],
          ),
        ),
      );
}
