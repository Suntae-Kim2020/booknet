import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';

class BookRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<List<Book>> myBooks() async {
    if (_uid.isEmpty) return [];
    try {
      final rows = await _db
          .from('books')
          .select()
          .eq('owner_id', _uid)
          .isFilter('deleted_at', null)
          .order('created_at');
      return (rows as List).map((e) => Book.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Book> upsertBook(Book book) async {
    final row = await _db
        .from('books')
        .upsert(book.toMap())
        .select()
        .single();
    return Book.fromMap(row);
  }

  Future<void> markRead(String bookId, bool isRead) async {
    await _db.from('books').update({
      'is_read': isRead,
      'read_at': isRead ? DateTime.now().toIso8601String() : null,
    }).eq('id', bookId);
  }

  /// 읽기 상태 설정: 'unread' / 'reading' / 'read'
  Future<void> setReadStatus(String bookId, String status) async {
    final data = <String, dynamic>{};
    switch (status) {
      case 'read':
        data['is_read'] = true;
        data['read_at'] = DateTime.now().toIso8601String();
      case 'reading':
        data['is_read'] = false;
        data['read_at'] = DateTime.now().toIso8601String();
      case 'unread':
      default:
        data['is_read'] = false;
        data['read_at'] = null;
    }
    await _db.from('books').update(data).eq('id', bookId);
  }

  Future<void> setForSale(String bookId, bool forSale) async {
    await _db.from('books').update({'is_for_sale': forSale}).eq('id', bookId);
  }

  Future<void> setWantsDiscussion(String bookId, bool wants) async {
    await _db
        .from('books')
        .update({'wants_discussion': wants})
        .eq('id', bookId);
  }

  /// 소프트 삭제 (deleted_at 설정 + 미판매 꾸러미에서 제거)
  Future<void> softDelete(String bookId) async {
    // 판매 완료/예약 중이 아닌 꾸러미에서만 제거
    final bundles = await _db
        .from('sale_bundles')
        .select('id, status')
        .eq('owner_id', _uid)
        .inFilter('status', ['listed', 'hidden']);
    final removableBundleIds =
        (bundles as List).map((e) => e['id'] as String).toList();
    if (removableBundleIds.isNotEmpty) {
      await _db
          .from('bundle_books')
          .delete()
          .eq('book_id', bookId)
          .inFilter('bundle_id', removableBundleIds);
    }
    // 서재에서 소프트 삭제
    await _db.from('books').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', bookId);
  }

  /// 삭제 전 연관 데이터 요약 조회
  Future<Map<String, dynamic>> deletionWarnings(String bookId) async {
    // 꾸러미에 포함 여부 (상태 포함)
    final bundles = await _db
        .from('bundle_books')
        .select('bundle_id, sale_bundles!inner(title, status)')
        .eq('book_id', bookId);
    final bundleCount = (bundles as List).length;

    // 독서토론에서 사용 중인지
    final discussions = await _db
        .from('discussions')
        .select('id, title, status')
        .or('book_id.eq.$bookId,current_book_id.eq.$bookId');
    final discList = (discussions as List).cast<Map<String, dynamic>>();

    // 토론 참가자가 있는지
    var hasParticipants = false;
    for (final d in discList) {
      final parts = await _db
          .from('discussion_participants')
          .select('id')
          .eq('discussion_id', d['id'] as String)
          .eq('status', 'joined')
          .limit(2);
      if ((parts as List).length > 1) {
        hasParticipants = true;
        break;
      }
    }

    return {
      'bundleCount': bundleCount,
      'bundles': (bundles as List)
          .map((b) => {
                'title': b['sale_bundles']['title'],
                'status': b['sale_bundles']['status'],
              })
          .toList(),
      'discussions': discList,
      'hasParticipants': hasParticipants,
    };
  }
}
