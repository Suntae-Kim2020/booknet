import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/bundle_book.dart';
import '../../models/sale_bundle.dart';

class BundleRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<List<SaleBundle>> myBundles() async {
    final rows = await _db
        .from('sale_bundles')
        .select('*, bundle_books(*, books(title, author, publisher, cover_url))')
        .eq('owner_id', _uid)
        .order('created_at');
    return (rows as List).map((e) => SaleBundle.fromMap(e)).toList();
  }

  Future<List<SaleBundle>> allBundles({String? bookQuery}) async {
    final rows = await _db
        .from('sale_bundles')
        .select('*, bundle_books(*, books(title, author, publisher, cover_url))')
        .eq('status', 'listed')
        .order('created_at', ascending: false);
    var list = (rows as List).map((e) => SaleBundle.fromMap(e)).toList();
    if (bookQuery != null && bookQuery.isNotEmpty) {
      list = list.where((b) => b.title.contains(bookQuery)).toList();
    }
    return list;
  }

  Future<SaleBundle> createBundle(SaleBundle bundle) async {
    final row = await _db
        .from('sale_bundles')
        .insert(bundle.toMap())
        .select()
        .single();
    // 개별 책 가격 insert
    for (final book in bundle.books) {
      await _db.from('bundle_books').insert({
        'bundle_id': row['id'],
        'book_id': book.bookId,
        'price_won': book.priceWon,
      });
      await _syncBookForSaleFlag(book.bookId);
    }
    return SaleBundle.fromMap(row);
  }

  Future<List<BundleBook>> bundleBooks(String bundleId) async {
    final rows = await _db
        .from('bundle_books')
        .select()
        .eq('bundle_id', bundleId);
    return (rows as List).map((e) => BundleBook.fromMap(e)).toList();
  }

  /// 특정 책이 포함된 꾸러미 목록 (현재 사용자 소유, 중복 제거)
  Future<List<SaleBundle>> bundlesContainingBook(String bookId) async {
    final rows = await _db
        .from('bundle_books')
        .select('bundle_id, sale_bundles!inner(*)')
        .eq('book_id', bookId)
        .eq('sale_bundles.owner_id', _uid);
    final seen = <String>{};
    final list = <SaleBundle>[];
    for (final e in rows as List) {
      final bundle = SaleBundle.fromMap(e['sale_bundles'] as Map<String, dynamic>);
      if (seen.add(bundle.id)) list.add(bundle);
    }
    return list;
  }

  /// 특정 꾸러미에서 책 제외
  Future<void> removeBookFromBundle(String bundleId, String bookId) async {
    await _db
        .from('bundle_books')
        .delete()
        .eq('bundle_id', bundleId)
        .eq('book_id', bookId);
    await _syncBookForSaleFlag(bookId);
  }

  /// 모든 꾸러미에서 책 일괄 제거
  Future<void> removeBookFromAllBundles(String bookId) async {
    // 본인 소유 꾸러미의 bundle_id 목록
    final rows = await _db
        .from('sale_bundles')
        .select('id')
        .eq('owner_id', _uid);
    final bundleIds =
        (rows as List).map((e) => e['id'] as String).toList();
    if (bundleIds.isEmpty) return;

    await _db
        .from('bundle_books')
        .delete()
        .eq('book_id', bookId)
        .inFilter('bundle_id', bundleIds);
    await _syncBookForSaleFlag(bookId);
  }

  /// books.is_for_sale 을 bundle_books 존재 여부에 맞춰 동기화
  Future<void> _syncBookForSaleFlag(String bookId) async {
    final rows = await _db
        .from('bundle_books')
        .select('book_id')
        .eq('book_id', bookId)
        .limit(1);
    final inAnyBundle = (rows as List).isNotEmpty;
    await _db
        .from('books')
        .update({'is_for_sale': inAnyBundle})
        .eq('id', bookId);
  }

  /// 꾸러미에 책 추가 (이미 있으면 가격만 업데이트)
  Future<void> addBookToBundle(
      String bundleId, String bookId, int priceWon) async {
    await _db.from('bundle_books').upsert({
      'bundle_id': bundleId,
      'book_id': bookId,
      'price_won': priceWon,
    }, onConflict: 'bundle_id,book_id');
    await _syncBookForSaleFlag(bookId);
  }

  /// 꾸러미 삭제 (cascade로 bundle_books도 제거됨)
  Future<void> deleteBundle(String bundleId) async {
    // 삭제 전에 포함된 book_id 목록 저장
    final rows = await _db
        .from('bundle_books')
        .select('book_id')
        .eq('bundle_id', bundleId);
    final bookIds =
        (rows as List).map((e) => e['book_id'] as String).toList();

    await _db.from('sale_bundles').delete().eq('id', bundleId);

    // 각 책의 is_for_sale 동기화
    for (final bookId in bookIds) {
      await _syncBookForSaleFlag(bookId);
    }
  }

  /// 꾸러미 내 책 가격 수정
  Future<void> updateBookPrice(
      String bundleId, String bookId, int priceWon) async {
    final rows = await _db
        .from('bundle_books')
        .update({'price_won': priceWon})
        .eq('bundle_id', bundleId)
        .eq('book_id', bookId)
        .select();
    if ((rows as List).isEmpty) {
      throw Exception('가격 수정이 차단되었습니다. RLS 정책을 확인하세요.');
    }
  }

  /// 단일 꾸러미 조회 (books 포함)
  Future<SaleBundle?> getBundle(String bundleId) async {
    final row = await _db
        .from('sale_bundles')
        .select('*, bundle_books(*, books(title, author, publisher, cover_url))')
        .eq('id', bundleId)
        .maybeSingle();
    if (row == null) return null;
    return SaleBundle.fromMap(row);
  }
}
