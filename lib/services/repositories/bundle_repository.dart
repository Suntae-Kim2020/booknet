import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/bundle_book.dart';
import '../../models/sale_bundle.dart';

class BundleRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<List<SaleBundle>> myBundles() async {
    final rows = await _db
        .from('sale_bundles')
        .select('*, bundle_books(*)')
        .eq('owner_id', _uid)
        .order('created_at');
    return (rows as List).map((e) => SaleBundle.fromMap(e)).toList();
  }

  Future<List<SaleBundle>> allBundles({String? bookQuery}) async {
    final rows = await _db
        .from('sale_bundles')
        .select('*, bundle_books(*)')
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
}
