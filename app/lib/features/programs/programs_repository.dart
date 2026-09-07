import '../../core/supabase.dart';
import 'program.dart';

/// قراءة وكتابة البرامج التشغيلية (منفصلة عن نصوص الموقع في content.js).
class ProgramsRepository {
  const ProgramsRepository();

  static const _cols = 'id, title, text, age_min, age_max, is_published, created_at, price, sibling_price';

  Future<List<Program>> fetch() async {
    final rows = await Db.client.from('programs').select(_cols).order('title');
    return (rows as List).map((r) => Program.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> create(Program p) async {
    await Db.client.from('programs').insert(p.toInsertMap());
  }

  Future<void> update(String id, Program p) async {
    await Db.client.from('programs').update(p.toInsertMap()).eq('id', id);
  }
}
