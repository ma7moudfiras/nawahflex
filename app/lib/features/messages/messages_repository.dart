import '../../core/supabase.dart';
import 'message.dart';

/// قراءة وتحديث الرسائل الواردة.
///
/// كل استدعاء هنا يمرّ عبر RLS: لن يعيد الخادم صفاً واحداً ما لم يكن
/// المستخدم admin أو editor — لا نعتمد على إخفاء الواجهة وحدها.
class MessagesRepository {
  const MessagesRepository();

  static const _cols = 'id, name, phone, email, interest, message, source, status, notes, created_at';

  Future<List<Message>> fetch({String? status}) async {
    var query = Db.client.from('messages').select(_cols);
    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    return (rows as List).map((r) => Message.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> setStatus(String id, String status) async {
    await Db.client.from('messages').update({'status': status}).eq('id', id);
  }

  Future<void> setNotes(String id, String notes) async {
    await Db.client.from('messages').update({'notes': notes}).eq('id', id);
  }

  /// عدّاد لكل حالة — يغذّي شارات التبويبات.
  Future<Map<String, int>> counts() async {
    final rows = await Db.client.from('messages').select('status');
    final out = <String, int>{'all': 0};
    for (final r in rows as List) {
      final s = (r as Map<String, dynamic>)['status'] as String? ?? 'new';
      out[s] = (out[s] ?? 0) + 1;
      out['all'] = out['all']! + 1;
    }
    return out;
  }
}
