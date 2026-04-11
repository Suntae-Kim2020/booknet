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

  Future<void> setForSale(String bookId, bool forSale) async {
    await _db.from('books').update({'is_for_sale': forSale}).eq('id', bookId);
  }

  Future<void> setWantsDiscussion(String bookId, bool wants) async {
    await _db
        .from('books')
        .update({'wants_discussion': wants})
        .eq('id', bookId);
  }
}
