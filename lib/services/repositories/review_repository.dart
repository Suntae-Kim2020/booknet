import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/review.dart';

class ReviewRepository {
  SupabaseClient get _db => Supabase.instance.client;

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

  Future<void> deleteReview(String reviewId) async {
    await _db.from('reviews').delete().eq('id', reviewId);
  }
}
