import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/discussion.dart';
import '../../models/discussion_interest.dart';
import '../../models/discussion_participant.dart';

class DiscussionRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  Future<List<Discussion>> searchDiscussions({
    String? bookQuery,
    String? region,
    bool? isOnline,
    String? genderPolicy,
    int? minAge,
    int? maxAge,
  }) async {
    var q = _db.from('discussions').select().eq('status', 'open');
    if (region != null && region.isNotEmpty) {
      q = q.ilike('region', '%$region%');
    }
    if (isOnline != null) {
      q = q.eq('is_online', isOnline);
    }
    if (genderPolicy != null && genderPolicy != 'any') {
      q = q.eq('gender_policy', genderPolicy);
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

  // ---------- Participants ----------
  Future<void> joinDiscussion(String discussionId) async {
    await _db.from('discussion_participants').upsert({
      'discussion_id': discussionId,
      'user_id': _uid,
      'status': 'joined',
    });
  }

  Future<void> leaveDiscussion(String discussionId) async {
    await _db
        .from('discussion_participants')
        .update({'status': 'left'})
        .eq('discussion_id', discussionId)
        .eq('user_id', _uid);
  }

  Future<List<DiscussionParticipant>> participants(
      String discussionId) async {
    final rows = await _db
        .from('discussion_participants')
        .select()
        .eq('discussion_id', discussionId)
        .eq('status', 'joined');
    return (rows as List)
        .map((e) => DiscussionParticipant.fromMap(e))
        .toList();
  }

  // ---------- Interests ----------
  Future<void> registerInterest(DiscussionInterest interest) async {
    await _db.from('discussion_interests').upsert(interest.toMap());
  }

  Future<void> removeInterest(String bookId) async {
    await _db
        .from('discussion_interests')
        .delete()
        .eq('user_id', _uid)
        .eq('book_id', bookId);
  }

  Future<List<DiscussionInterest>> interestedUsers(String bookId) async {
    final rows = await _db
        .from('discussion_interests')
        .select()
        .eq('book_id', bookId);
    return (rows as List)
        .map((e) => DiscussionInterest.fromMap(e))
        .toList();
  }
}
