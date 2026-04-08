import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/discussion.dart';
import '../models/review.dart';
import '../models/sale_bundle.dart';

/// Supabase 저장소 래퍼.
/// 테이블 스키마는 docs/supabase_schema.sql 참조.
class SupabaseRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ---------- Books ----------
  Future<List<Book>> myBooks() async {
    final rows = await _db.from('books').select().order('created_at');
    return (rows as List).map((e) => Book.fromMap(e)).toList();
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

  Future<void> setForSale(String bookId, bool forSale) async {
    await _db.from('books').update({'is_for_sale': forSale}).eq('id', bookId);
  }

  Future<void> setWantsDiscussion(String bookId, bool wants) async {
    await _db
        .from('books')
        .update({'wants_discussion': wants}).eq('id', bookId);
  }

  // ---------- Bundles ----------
  Future<List<SaleBundle>> myBundles() async {
    final rows = await _db.from('sale_bundles').select().order('created_at');
    return (rows as List).map((e) => SaleBundle.fromMap(e)).toList();
  }

  Future<SaleBundle> createBundle(SaleBundle bundle) async {
    final row = await _db
        .from('sale_bundles')
        .insert(bundle.toMap())
        .select()
        .single();
    return SaleBundle.fromMap(row);
  }

  // ---------- Discussions ----------
  Future<List<Discussion>> searchDiscussions({
    String? bookQuery,
    String? region,
    bool? isOnline,
  }) async {
    var q = _db.from('discussions').select();
    if (region != null && region.isNotEmpty) {
      q = q.ilike('region', '%$region%');
    }
    if (isOnline != null) {
      q = q.eq('is_online', isOnline);
    }
    final rows = await q.order('scheduled_at');
    var list = (rows as List).map((e) => Discussion.fromMap(e)).toList();
    if (bookQuery != null && bookQuery.isNotEmpty) {
      list = list.where((d) => d.title.contains(bookQuery)).toList();
    }
    return list;
  }

  Future<Discussion> createDiscussion(Discussion d) async {
    final row = await _db
        .from('discussions')
        .insert(d.toMap())
        .select()
        .single();
    return Discussion.fromMap(row);
  }

  // ---------- Reviews ----------
  Future<List<Review>> reviewsForBook(String bookId) async {
    final rows = await _db
        .from('reviews')
        .select()
        .eq('book_id', bookId)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => Review.fromMap(e)).toList();
  }

  Future<List<Review>> recentReviews({int limit = 50}) async {
    final rows = await _db
        .from('reviews')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => Review.fromMap(e)).toList();
  }

  Future<Review> addReview(Review r) async {
    final row =
        await _db.from('reviews').insert(r.toMap()).select().single();
    return Review.fromMap(row);
  }
}
