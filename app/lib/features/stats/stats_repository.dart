import '../../core/supabase.dart';
import 'stat_item.dart';

/// قراءة وكتابة بطاقات الإحصائيات — نفس الجدول الذي يقرأه الموقع مباشرة
/// عبر anon key (site/js/api.js)، فأي حفظ هنا ينعكس على الموقع فوراً.
class StatsRepository {
  const StatsRepository();

  static const _cols = 'id, label, value, suffix, icon, sort_order, is_published';

  Future<List<StatItem>> fetch() async {
    final rows = await Db.client.from('stats').select(_cols).order('sort_order');
    return (rows as List).map((r) => StatItem.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> create(StatItem s) async {
    await Db.client.from('stats').insert(s.toInsertMap());
  }

  Future<void> update(String id, StatItem s) async {
    await Db.client.from('stats').update(s.toInsertMap()).eq('id', id);
  }
}
