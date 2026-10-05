import 'dart:async';

import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../core/open_url.dart';
import '../../shared/adaptive.dart';
import '../../shared/sheets.dart';
import '../attendance/attendance_repository.dart';
import '../attendance/attendance_status.dart';
import '../programs/program.dart';
import '../programs/programs_repository.dart';
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
  final _programsRepo = const ProgramsRepository();
  final _search = TextEditingController();
  List<Student> _items = [];
  List<Program> _programs = [];
  Student? _selected;
  bool _activeOnly = true;
  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // فشل تحميل البرامج ليس مانعاً لإدارة الطلاب — يُخفي فقط قسم الاختيار
    // المتعدد في النموذج (StudentForm يتعامل مع قائمة فارغة بصمت).
    _programsRepo
        .fetch()
        .then((p) {
          if (mounted) setState(() => _programs = p);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Timer? _debounce;
  void _onSearchChanged(String _) {
    setState(() {}); // إظهار/إخفاء زر المسح
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetch(
        query: _search.text,
        activeOnly: _activeOnly,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _loadedOnce = true;
        if (_selected != null && !items.any((s) => s.id == _selected!.id)) {
          _selected = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الطلاب. تحقّق من اتصالك ثم أعد المحاولة.';
      });
    }
  }

  Future<void> _openForm({Student? existing}) async {
    final initialProgramIds = existing == null
        ? <String>[]
        : await _repo.fetchProgramIds(existing.id);
    if (!mounted) return;

    Future<void> onSubmit(Student s, List<String> programIds) async {
      final id = existing == null ? await _repo.create(s) : existing.id;
      if (existing != null) await _repo.update(existing.id, s);
      await _repo.setPrograms(id, programIds);
      await _load();
    }

    await showAdaptiveSheet<void>(
      context,
      builder: (_) => StudentForm(
        initial: existing,
        onSubmit: onSubmit,
        allPrograms: _programs,
        initialProgramIds: initialProgramIds,
      ),
    );
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    if (!await openExternal(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // دائرة التحميل تملأ الشاشة في التحميل الأول فقط — لو ظهرت أثناء البحث
    // لاستبدلت حقل البحث نفسه وأغلقت لوحة المفاتيح بعد كل حرف.
    if (_loading && !_loadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Empty(
        icon: Icons.wifi_off,
        title: 'تعذّر التحميل',
        subtitle: _error!,
        action: FilledButton.tonal(
          onPressed: _load,
          child: const Text('إعادة المحاولة'),
        ),
      );
    }

    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NawahSpacing.s4,
            NawahSpacing.s4,
            NawahSpacing.s4,
            0,
          ),
          // البحث يجري أثناء الكتابة (بعد توقّف قصير) — لا زر «بحث» ولا
          // حاجة لضغط Enter على لوحة مفاتيح الجوّال.
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _load(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                      },
                    ),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NawahSpacing.s4,
            NawahSpacing.s3,
            NawahSpacing.s4,
            0,
          ),
          child: Row(
            children: [
              FilterChip(
                label: const Text('النشطون فقط'),
                selected: _activeOnly,
                onSelected: (v) {
                  setState(() => _activeOnly = v);
                  _load();
                },
              ),
              const Spacer(),
              Text(
                '${_items.length} طالب',
                style: const TextStyle(
                  color: NawahColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? (_search.text.trim().isNotEmpty
                  ? _Empty(
                      icon: Icons.search_off,
                      title: 'لا نتائج',
                      subtitle: 'لا يوجد طالب باسم يحوي «${_search.text.trim()}».',
                    )
                  : const _Empty(
                      icon: Icons.groups_outlined,
                      title: 'لا يوجد طلاب بعد',
                      subtitle: 'اضغط زر الإضافة لتسجيل أول طالب.',
                    ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    // المسافة السفلية تُبقي آخر طالب ظاهراً فوق زر الإضافة.
                    padding: const EdgeInsets.fromLTRB(
                      NawahSpacing.s4,
                      NawahSpacing.s4,
                      NawahSpacing.s4,
                      96,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: NawahSpacing.s2),
                    itemBuilder: (_, i) {
                      final s = _items[i];
                      return _StudentTile(
                        student: s,
                        selected: context.isWide && _selected?.id == s.id,
                        onTap: () {
                          if (context.isWide) {
                            setState(() => _selected = s);
                          } else {
                            var current = s;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                // الصفحة تُحدّث نفسها بعد التعديل — كانت تعرض
                                // البيانات القديمة حتى يعود المستخدم ويفتحها.
                                builder: (_) => StatefulBuilder(
                                  builder: (ctx, setPage) => Scaffold(
                                    // الاسم يظهر عنواناً كبيراً في الصفحة نفسها؛
                                    // تكراره في الشريط يقصّه وبلا فائدة.
                                    appBar: AppBar(
                                      title: const Text('بيانات الطالب'),
                                      actions: [
                                        IconButton(
                                          tooltip: 'تعديل',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () async {
                                            await _openForm(existing: current);
                                            final fresh = _items.where(
                                              (x) => x.id == current.id,
                                            );
                                            if (fresh.isNotEmpty) {
                                              setPage(() => current = fresh.first);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    body: _Detail(student: current, onOpen: _open),
                                  ),
                                ),
                              ),
                            );
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
              SizedBox(
                width: adaptive(
                  context,
                  mobile: 320.0,
                  tablet: 320.0,
                  desktop: 380.0,
                ),
                child: list,
              ),
              const VerticalDivider(width: 1, color: NawahColors.border),
              Expanded(
                child: _selected == null
                    ? const _Empty(
                        icon: Icons.touch_app_outlined,
                        title: 'اختر طالباً',
                        subtitle: 'اضغط على أي طالب من القائمة لعرض بياناته.',
                      )
                    : _Detail(
                        student: _selected!,
                        onOpen: _open,
                        onEdit: () => _openForm(existing: _selected),
                      ),
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
  const _StudentTile({
    required this.student,
    required this.selected,
    required this.onTap,
  });
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
            border: Border.all(
              color: selected ? NawahColors.primary : NawahColors.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: student.isActive
                    ? NawahColors.primary
                    : NawahColors.textMuted,
                child: Text(
                  student.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: NawahSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: NawahColors.ink,
                      ),
                    ),
                    if (student.guardianName != null &&
                        student.guardianName!.isNotEmpty)
                      Text(
                        'ولي الأمر: ${student.guardianName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: NawahColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (student.age != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: NawahColors.bgAlt,
                    borderRadius: BorderRadius.circular(NawahRadius.full),
                  ),
                  child: Text(
                    '${student.age}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatefulWidget {
  const _Detail({required this.student, required this.onOpen, this.onEdit});
  final Student student;
  final ValueChanged<String> onOpen;
  final VoidCallback? onEdit;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final _attendanceRepo = const AttendanceRepository();
  Map<String, int>? _attendanceCounts;

  Student get student => widget.student;
  ValueChanged<String> get onOpen => widget.onOpen;
  VoidCallback? get onEdit => widget.onEdit;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void didUpdateWidget(covariant _Detail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.id != widget.student.id) _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final targetId = widget.student.id;
    setState(() => _attendanceCounts = null);
    try {
      final counts = await _attendanceRepo.fetchStudentAttendanceCounts(
        targetId,
      );
      // تجاهل النتيجة إن انتقلت الشاشة لطالب آخر أثناء الجلب.
      if (mounted && widget.student.id == targetId) {
        setState(() => _attendanceCounts = counts);
      }
    } catch (e) {
      if (mounted && widget.student.id == targetId) {
        setState(() => _attendanceCounts = const {});
      }
    }
  }

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
                child: Text(
                  student.fullName,
                  style: const TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: NawahColors.ink,
                  ),
                ),
              ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('تعديل'),
                ),
            ],
          ),
          if (student.age != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${student.age} سنة${student.gender == 'm'
                    ? ' · ذكر'
                    : student.gender == 'f'
                    ? ' · أنثى'
                    : ''}',
                style: const TextStyle(
                  color: NawahColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),

          if (student.programTitles.isNotEmpty) ...[
            const SizedBox(height: NawahSpacing.s3),
            Wrap(
              spacing: NawahSpacing.s2,
              runSpacing: NawahSpacing.s2,
              children: student.programTitles
                  .map(
                    (t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      backgroundColor: NawahColors.primarySoft,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: NawahSpacing.s5),
          if (student.guardianName != null &&
              student.guardianName!.isNotEmpty) ...[
            const Text(
              'ولي الأمر',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: NawahColors.ink,
              ),
            ),
            const SizedBox(height: NawahSpacing.s2),
            Text(
              student.guardianName!,
              style: const TextStyle(color: NawahColors.textSoft),
            ),
            const SizedBox(height: NawahSpacing.s4),
            Wrap(
              spacing: NawahSpacing.s2,
              children: [
                if (student.guardianPhone != null &&
                    student.guardianPhone!.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () => onOpen(student.whatsappUrl),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('واتساب'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onOpen('tel:${student.guardianPhone}'),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(
                      student.guardianPhone!,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
                if (student.guardianEmail != null &&
                    student.guardianEmail!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onOpen('mailto:${student.guardianEmail}'),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(
                      student.guardianEmail!,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
          ],

          if (student.notes != null && student.notes!.isNotEmpty) ...[
            const SizedBox(height: NawahSpacing.s5),
            const Text(
              'ملاحظات',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: NawahColors.ink,
              ),
            ),
            const SizedBox(height: NawahSpacing.s2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(NawahSpacing.s4),
              decoration: BoxDecoration(
                color: NawahColors.bgAlt,
                borderRadius: BorderRadius.circular(NawahRadius.sm),
              ),
              child: Text(
                student.notes!,
                style: const TextStyle(color: NawahColors.text, height: 1.8),
              ),
            ),
          ],

          const SizedBox(height: NawahSpacing.s5),
          const Text(
            'الحضور',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: NawahColors.ink,
            ),
          ),
          const SizedBox(height: NawahSpacing.s2),
          _AttendanceSummary(counts: _attendanceCounts),
        ],
      ),
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({required this.counts});
  final Map<String, int>? counts;

  @override
  Widget build(BuildContext context) {
    final c = counts;
    if (c == null) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final total = c.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return const Text(
        'لا يوجد سجلّ حضور بعد',
        style: TextStyle(color: NawahColors.textMuted, fontSize: 13),
      );
    }
    final present =
        (c[AttendanceStatus.present] ?? 0) + (c[AttendanceStatus.late] ?? 0);
    final rate = (present / total * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$rate% نسبة الحضور ($present من $total حصة)',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: NawahColors.ink,
          ),
        ),
        const SizedBox(height: NawahSpacing.s2),
        Wrap(
          spacing: NawahSpacing.s2,
          runSpacing: NawahSpacing.s2,
          children: AttendanceStatus.all.where((s) => (c[s] ?? 0) > 0).map((s) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: NawahColors.bgAlt,
                borderRadius: BorderRadius.circular(NawahRadius.full),
              ),
              child: Text(
                '${AttendanceStatus.labels[s]}: ${c[s]}',
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
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
          Text(
            title,
            style: const TextStyle(
              fontFamily: NawahFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: NawahColors.ink,
            ),
          ),
          const SizedBox(height: NawahSpacing.s2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NawahColors.textSoft, height: 1.7),
          ),
          if (action != null) ...[
            const SizedBox(height: NawahSpacing.s5),
            action!,
          ],
        ],
      ),
    ),
  );
}
