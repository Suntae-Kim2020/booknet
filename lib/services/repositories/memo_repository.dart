import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/memo.dart';

class MemoRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<List<Memo>> memosForBook(String bookId) async {
    final rows = await _db
        .from('memos')
        .select()
        .eq('book_id', bookId)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => Memo.fromMap(e)).toList();
  }

  Future<List<Memo>> myMemos({int limit = 100}) async {
    final rows = await _db
        .from('memos')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => Memo.fromMap(e)).toList();
  }

  Future<Memo> createMemo({
    required String bookId,
    required String content,
    int? pageNumber,
    bool isShared = true,
  }) async {
    final row = await _db.from('memos').insert({
      'book_id': bookId,
      'user_id': _uid,
      'content': content,
      'page_number': pageNumber,
      'is_shared': isShared,
    }).select().single();
    return Memo.fromMap(row);
  }

  Future<Memo> updateMemo(Memo memo) async {
    final row = await _db
        .from('memos')
        .update({
          'content': memo.content,
          'page_number': memo.pageNumber,
          'is_shared': memo.isShared,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', memo.id)
        .select()
        .single();
    return Memo.fromMap(row);
  }

  Future<void> deleteMemo(String memoId) async {
    await _db.from('memos').delete().eq('id', memoId);
  }

  Future<List<Memo>> searchMemos(String query) async {
    final rows = await _db
        .from('memos')
        .select()
        .eq('is_shared', true)
        .ilike('content', '%$query%')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((e) => Memo.fromMap(e)).toList();
  }
}
