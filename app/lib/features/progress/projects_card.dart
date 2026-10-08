import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../core/image_prep.dart';
import '../../shared/form_error.dart';
import '../../shared/section_card.dart';
import '../../shared/sheets.dart';
import 'progress_models.dart';
import 'progress_repository.dart';

const _repo = ProgressRepository();

/// «المشاريع» — ما بناه الطالب بالصور. يظهر في ملف الطالب (الفريق)، وملف
/// الابن (ولي الأمر)، و«ملفّي» (الطالب). الإضافة والحذف لمن يدرّسه فقط.
class ProjectsCard extends StatelessWidget {
  const ProjectsCard({
    super.key,
    required this.studentId,
    required this.projects,
    required this.canEdit,
    required this.onChanged,
    this.title = 'المشاريع',
  });

  final String studentId;
  final List<StudentProject> projects;
  final bool canEdit;
  final VoidCallback onChanged;
  final String title;

  Future<void> _add(BuildContext context) async {
    final added = await showAdaptiveSheet<bool>(context, builder: (_) => _AddProjectSheet(studentId: studentId));
    if (added == true) onChanged();
  }

  Future<void> _open(BuildContext context, StudentProject p) async {
    final deleted = await showAdaptiveSheet<bool>(
      context,
      maxWidth: 640,
      builder: (_) => _ProjectSheet(project: p, canDelete: canEdit),
    );
    if (deleted == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: Icons.precision_manufacturing_outlined,
      action: canEdit
          ? TextButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add, size: 18), label: const Text('مشروع'))
          : null,
      child: projects.isEmpty
          ? const Text(
              'لا مشاريع بعد. كل مشروع يُضاف بصورته ويمنح ٣٠ نقطة.',
              style: TextStyle(color: NawahColors.textMuted, fontSize: 13, height: 1.7),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final perRow = box.maxWidth < 420 ? 2 : 3;
                final w = (box.maxWidth - NawahSpacing.s3 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: NawahSpacing.s3,
                  runSpacing: NawahSpacing.s3,
                  children: [
                    for (final p in projects)
                      SizedBox(width: w, child: _ProjectTile(project: p, onTap: () => _open(context, p))),
                  ],
                );
              },
            ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.onTap});
  final StudentProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NawahRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NawahRadius.sm),
              child: ProjectPhoto(path: project.photoPath),
            ),
          ),
          const SizedBox(height: NawahSpacing.s1),
          Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (project.rating != null) _Rating(project.rating!),
        ],
      ),
    );
  }
}

/// صورة مشروع من التخزين الخاص برابط موقّع؛ بلا صورة → أيقونة على الورق.
class ProjectPhoto extends StatelessWidget {
  const ProjectPhoto({super.key, required this.path, this.fit = BoxFit.cover});
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: NawahColors.paperDeep,
      child: Center(child: Icon(Icons.precision_manufacturing_outlined, color: NawahColors.textMuted, size: 32)),
    );
    final p = path;
    if (p == null) return placeholder;
    return FutureBuilder<String>(
      future: _repo.photoUrl(p),
      builder: (context, snap) {
        if (!snap.hasData) return snap.hasError ? placeholder : const ColoredBox(color: NawahColors.paperDeep);
        return Image.network(
          snap.data!,
          fit: fit,
          errorBuilder: (_, _, _) => placeholder,
          loadingBuilder: (_, child, progress) => progress == null ? child : const ColoredBox(color: NawahColors.paperDeep),
        );
      },
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating(this.value);
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'تقييم المدرّب $value من ٥',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14, color: i <= value ? NawahColors.ink : NawahColors.border),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class _ProjectSheet extends StatefulWidget {
  const _ProjectSheet({required this.project, required this.canDelete});
  final StudentProject project;
  final bool canDelete;

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المشروع؟'),
        content: const Text('تُحذف الصورة معه، وتنقص نقاط الطالب ٣٠ نقطة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.deleteProject(widget.project);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NawahSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(NawahRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ProjectPhoto(path: p.photoPath, fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: NawahSpacing.s3),
            Text(p.title, style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink)),
            const SizedBox(height: NawahSpacing.s1),
            Row(
              children: [
                Text(DateFormat('d MMMM y', 'ar').format(p.createdAt), style: const TextStyle(color: NawahColors.textMuted, fontSize: 12)),
                if (p.rating != null) ...[const SizedBox(width: NawahSpacing.s2), _Rating(p.rating!)],
              ],
            ),
            if (p.description != null) ...[
              const SizedBox(height: NawahSpacing.s3),
              Text(p.description!, style: const TextStyle(height: 1.8)),
            ],
            if (widget.canDelete) ...[
              const SizedBox(height: NawahSpacing.s4),
              FormErrorBanner(message: _error),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: NawahColors.err),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف المشروع'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddProjectSheet extends StatefulWidget {
  const _AddProjectSheet({required this.studentId});
  final String studentId;

  @override
  State<_AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<_AddProjectSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  Uint8List? _jpeg;
  int? _rating;
  bool _busy = false;
  bool _preparing = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      final raw = await files.first.readAsBytes();
      final jpeg = prepareImage(raw);
      if (!mounted) return;
      setState(() {
        _jpeg = jpeg;
        _error = jpeg == null ? 'تعذّرت قراءة الصورة. جرّب صورة JPEG أو PNG.' : null;
      });
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'اكتب عنوان المشروع.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.addProject(
        studentId: widget.studentId,
        title: _title.text,
        description: _description.text,
        rating: _rating,
        jpeg: _jpeg,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userMessageFor(e, st);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NawahSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('مشروع جديد',
                  style: TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink)),
              const SizedBox(height: NawahSpacing.s4),
              // الصورة
              InkWell(
                onTap: _busy || _preparing ? null : _pick,
                borderRadius: BorderRadius.circular(NawahRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: NawahColors.paper,
                      borderRadius: BorderRadius.circular(NawahRadius.md),
                      border: Border.all(color: NawahColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _preparing
                        ? const Center(child: CircularProgressIndicator())
                        : _jpeg != null
                            ? Image.memory(_jpeg!, fit: BoxFit.cover)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 36, color: NawahColors.textMuted),
                                  SizedBox(height: NawahSpacing.s1),
                                  Text('أضف صورة المشروع', style: TextStyle(color: NawahColors.textMuted)),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: NawahSpacing.s3),
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'العنوان', hintText: 'مثال: روبوت يتبع الخط', counterText: ''),
              ),
              const SizedBox(height: NawahSpacing.s3),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'وصف قصير (اختياري)', counterText: ''),
              ),
              const SizedBox(height: NawahSpacing.s3),
              const Text('تقييم المدرّب (اختياري)', style: TextStyle(fontSize: 13, color: NawahColors.textMuted)),
              const SizedBox(height: NawahSpacing.s1),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i من ٥',
                      onPressed: _busy ? null : () => setState(() => _rating = _rating == i ? null : i),
                      icon: Icon(
                        (_rating ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: (_rating ?? 0) >= i ? NawahColors.ink : NawahColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: NawahSpacing.s3),
              FormErrorBanner(message: _error),
              FilledButton(
                onPressed: _busy || _preparing ? null : _save,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ المشروع'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
