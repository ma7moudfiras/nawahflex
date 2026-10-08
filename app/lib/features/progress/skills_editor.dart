import 'package:flutter/material.dart';

import '../../brand/tokens.dart';
import '../../core/errors.dart';
import '../../shared/form_error.dart';
import '../../shared/sheets.dart';
import 'progress_models.dart';
import 'progress_repository.dart';

/// مهارات برنامج: ما يقيّمه المدرّب لكل طالب فيه (مبتدئ → خبير).
/// للإدارة فقط — RLS ترفض الكتابة لغيرها.
Future<void> showSkillsEditor(BuildContext context, {required String programId, required String programTitle}) {
  return showAdaptiveSheet<void>(
    context,
    maxWidth: 520,
    builder: (_) => _SkillsEditor(programId: programId, programTitle: programTitle),
  );
}

class _SkillsEditor extends StatefulWidget {
  const _SkillsEditor({required this.programId, required this.programTitle});
  final String programId;
  final String programTitle;

  @override
  State<_SkillsEditor> createState() => _SkillsEditorState();
}

class _SkillsEditorState extends State<_SkillsEditor> {
  static const _repo = ProgressRepository();
  final _title = TextEditingController();
  List<Skill>? _skills;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.fetchSkills([widget.programId]);
      if (mounted) setState(() => _skills = s);
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    }
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
      await _load();
    } catch (e, st) {
      if (mounted) setState(() => _error = userMessageFor(e, st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    await _run(() => _repo.addSkill(widget.programId, t, sortOrder: (_skills?.length ?? 0) + 1));
    if (_error == null) _title.clear();
  }

  Future<void> _delete(Skill s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف «${s.title}»؟'),
        content: const Text('تُحذف معها درجات كل الطلاب في هذه المهارة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await _run(() => _repo.deleteSkill(s.id));
  }

  @override
  Widget build(BuildContext context) {
    final skills = _skills;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مهارات ${widget.programTitle}',
                style: const TextStyle(fontFamily: NawahFonts.display, fontWeight: FontWeight.w800, fontSize: 18, color: NawahColors.ink),
              ),
              const SizedBox(height: NawahSpacing.s1),
              const Text(
                'ما يقيّمه المدرّب لكل طالب في البرنامج، ويراه ولي الأمر شريط تقدّم.',
                style: TextStyle(color: NawahColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: NawahSpacing.s4),
              FormErrorBanner(message: _error),
              if (skills == null)
                const Padding(
                  padding: EdgeInsets.all(NawahSpacing.s4),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (skills.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: NawahSpacing.s3),
                  child: Text('لا مهارات بعد. أضف أولها — مثلاً «تركيب المحرّكات» أو «الحلقات التكرارية».',
                      style: TextStyle(color: NawahColors.textSoft, height: 1.7)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in skills)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insights_outlined, color: NawahColors.ink),
                          title: Text(s.title),
                          trailing: IconButton(
                            tooltip: 'حذف',
                            onPressed: _busy ? null : () => _delete(s),
                            icon: const Icon(Icons.delete_outline, color: NawahColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: NawahSpacing.s2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      enabled: !_busy,
                      maxLength: 80,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(hintText: 'مهارة جديدة', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: NawahSpacing.s2),
                  FilledButton(
                    onPressed: _busy ? null : _add,
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('إضافة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
