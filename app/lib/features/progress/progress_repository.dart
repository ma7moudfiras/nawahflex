import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/errors.dart';
import '../../core/supabase.dart';
import 'progress_models.dart';

/// قراءة وكتابة التقدّم. الصلاحية في RLS (0012): من يدرّس الطالب يكتب،
/// ومن يدرّسه أو وليّه يقرأ. الواجهة لا تقرّر شيئاً هنا.
class ProgressRepository {
  const ProgressRepository();

  /// النقاط والمستوى لعدّة طلاب في طلب واحد — الطالب الذي لا يملك السائل
  /// رؤيته يغيب من النتيجة، فيُعرض بمستواه الأول.
  Future<Map<String, StudentProgress>> fetchProgress(List<String> studentIds) async {
    if (studentIds.isEmpty) return const {};
    final rows = await Db.client.rpc('student_progress', params: {'p_student_ids': studentIds});
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['student_id'] as String: StudentProgress.fromMap(r),
    };
  }

  Future<StudentProgress> fetchOne(String studentId) async =>
      (await fetchProgress([studentId]))[studentId] ?? StudentProgress.empty(studentId);

  /// المستويات وعتباتها (جدول levels) — لشرح الإطار والمستوى التالي.
  Future<List<({int level, String title, int minPoints})>> fetchLevels() async {
    final rows = await Db.client.from('levels').select('level, title, min_points').order('level', ascending: true);
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        (
          level: (r['level'] as num).toInt(),
          title: r['title'] as String,
          minPoints: (r['min_points'] as num).toInt(),
        ),
    ];
  }

  // ---------- الشارات ----------

  Future<List<BadgeDef>> fetchBadgeCatalog() async {
    final rows = await Db.client
        .from('badges')
        .select('id, key, title, description, icon, points, program_id, is_active')
        .order('sort_order', ascending: true)
        .order('title', ascending: true);
    return (rows as List).map((r) => BadgeDef.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<EarnedBadge>> fetchEarnedBadges(String studentId) async {
    final rows = await Db.client
        .from('student_badges')
        .select('id, badge_id, awarded_by, note, awarded_at')
        .eq('student_id', studentId)
        .order('awarded_at', ascending: false);
    return (rows as List).map((r) => EarnedBadge.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> awardBadge(String studentId, String badgeId, {String? note}) async {
    await Db.client.from('student_badges').insert({
      'student_id': studentId,
      'badge_id': badgeId,
      'awarded_by': Db.user!.id,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> revokeBadge(String earnedId) async {
    expectRows(await Db.client.from('student_badges').delete().eq('id', earnedId).select('id'));
  }

  // ---------- المهارات ----------

  Future<List<Skill>> fetchSkills(List<String> programIds) async {
    if (programIds.isEmpty) return const [];
    final rows = await Db.client
        .from('skills')
        .select('id, program_id, title, description, sort_order')
        .inFilter('program_id', programIds)
        .order('sort_order', ascending: true)
        .order('title', ascending: true);
    return (rows as List).map((r) => Skill.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// درجة الطالب في كل مهارة: skill_id → ١..٤
  Future<Map<String, int>> fetchSkillLevels(String studentId) async {
    final rows = await Db.client
        .from('student_skill_levels')
        .select('skill_id, level')
        .eq('student_id', studentId);
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['skill_id'] as String: (r['level'] as num).toInt(),
    };
  }

  Future<void> setSkillLevel(String studentId, String skillId, int level) async {
    expectRows(await Db.client.from('student_skill_levels').upsert({
      'student_id': studentId,
      'skill_id': skillId,
      'level': level,
      'updated_by': Db.user!.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select('skill_id'));
  }

  Future<void> addSkill(String programId, String title, {int sortOrder = 0}) async {
    await Db.client.from('skills').insert({
      'program_id': programId,
      'title': title.trim(),
      'sort_order': sortOrder,
    });
  }

  Future<void> renameSkill(String skillId, String title) async {
    expectRows(await Db.client.from('skills').update({'title': title.trim()}).eq('id', skillId).select('id'));
  }

  Future<void> deleteSkill(String skillId) async {
    expectRows(await Db.client.from('skills').delete().eq('id', skillId).select('id'));
  }

  // ---------- الملاحظات ----------

  Future<List<StudentNote>> fetchNotes(String studentId, {int limit = 30}) async {
    final rows = await Db.client
        .from('student_notes')
        .select('id, body, created_at, visible_to_guardian, author_id')
        .eq('student_id', studentId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => StudentNote.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addNote(String studentId, String body, {required bool visibleToGuardian}) async {
    await Db.client.from('student_notes').insert({
      'student_id': studentId,
      'body': body.trim(),
      'visible_to_guardian': visibleToGuardian,
      'author_id': Db.user!.id,
    });
  }

  Future<void> deleteNote(String noteId) async {
    expectRows(await Db.client.from('student_notes').delete().eq('id', noteId).select('id'));
  }

  // ---------- المشاريع ----------

  static const _bucket = 'student-projects';

  /// روابط موقّعة مخزّنة مؤقتاً — كي لا يطلب كل إعادة رسم رابطاً جديداً.
  static final Map<String, ({String url, DateTime until})> _signed = {};

  Future<List<StudentProject>> fetchProjects(String studentId) async {
    final rows = await Db.client
        .from('student_projects')
        .select('id, student_id, title, description, photo_path, rating, created_by, created_at')
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => StudentProject.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// يرفع الصورة (مصغّرة مسبقاً بـ prepareImage) ثم يسجّل المشروع. إن فشل
  /// التسجيل تُحذف الصورة كي لا يبقى ملف يتيم في التخزين.
  Future<void> addProject({
    required String studentId,
    required String title,
    String? description,
    int? rating,
    Uint8List? jpeg,
  }) async {
    String? path;
    if (jpeg != null) {
      path = '$studentId/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await Db.client.storage.from(_bucket).uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }
    try {
      await Db.client.from('student_projects').insert({
        'student_id': studentId,
        'title': title.trim(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        'rating': ?rating,
        'photo_path': ?path,
        'created_by': Db.user!.id,
      });
    } catch (_) {
      if (path != null) await _removeQuietly(path);
      rethrow;
    }
  }

  Future<void> deleteProject(StudentProject p) async {
    expectRows(await Db.client.from('student_projects').delete().eq('id', p.id).select('id'));
    if (p.photoPath != null) {
      _signed.remove(p.photoPath);
      // الصفّ حُذف؛ فشل حذف الملف لا يُفشل العملية (يبقى خاصاً غير مرئي).
      await _removeQuietly(p.photoPath!);
    }
  }

  /// حذف ملف لا يُفشل العملية الأصلية إن تعذّر — يبقى خاصاً لا يراه أحد.
  Future<void> _removeQuietly(String path) async {
    try {
      await Db.client.storage.from(_bucket).remove([path]);
    } catch (_) {}
  }

  /// رابط موقّع لساعة، يُجدَّد قبل انتهائه بخمس دقائق.
  Future<String> photoUrl(String path) async {
    final hit = _signed[path];
    if (hit != null && hit.until.isAfter(DateTime.now())) return hit.url;
    final url = await Db.client.storage.from(_bucket).createSignedUrl(path, 3600);
    _signed[path] = (url: url, until: DateTime.now().add(const Duration(minutes: 55)));
    return url;
  }
}
