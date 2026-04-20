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
    int? userAge,
  }) async {
    // 책 정보를 embed해서 함께 가져옴 (book_id FK)
    var q = _db
        .from('discussions')
        .select('*, books!book_id(title, author)')
        .eq('status', 'open');
    if (region != null && region.isNotEmpty) {
      q = q.ilike('region', '%$region%');
    }
    if (isOnline != null) {
      q = q.eq('is_online', isOnline);
    }
    if (genderPolicy != null && genderPolicy != 'any') {
      q = q.or('gender_policy.eq.any,gender_policy.eq.$genderPolicy');
    }
    final rows = await q.order('scheduled_at');
    var raw = (rows as List).cast<Map<String, dynamic>>();

    // 책 제목/저자/토론방 제목 중 하나라도 매칭되면 통과
    if (bookQuery != null && bookQuery.trim().isNotEmpty) {
      final kw = bookQuery.trim().toLowerCase();
      raw = raw.where((row) {
        final b = row['books'] as Map?;
        final bt = (b?['title'] as String?)?.toLowerCase() ?? '';
        final ba = (b?['author'] as String?)?.toLowerCase() ?? '';
        final dt = (row['title'] as String?)?.toLowerCase() ?? '';
        return bt.contains(kw) || ba.contains(kw) || dt.contains(kw);
      }).toList();
    }

    var list = raw.map((e) => Discussion.fromMap(e)).toList();
    if (userAge != null) {
      list = list.where((d) {
        if (d.minAge != null && userAge < d.minAge!) return false;
        if (d.maxAge != null && userAge > d.maxAge!) return false;
        return true;
      }).toList();
    }
    return list;
  }

  Future<Discussion?> getDiscussion(String id) async {
    final row = await _db
        .from('discussions')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Discussion.fromMap(row);
  }

  Future<List<Discussion>> myDiscussions() async {
    final rows = await _db
        .from('discussion_participants')
        .select('discussion_id, discussions!inner(*)')
        .eq('user_id', _uid)
        .eq('status', 'joined');
    final seen = <String>{};
    final list = <Discussion>[];
    for (final e in rows as List) {
      final d = Discussion.fromMap(e['discussions'] as Map<String, dynamic>);
      if (seen.add(d.id)) list.add(d);
    }
    return list;
  }

  Future<void> deleteDiscussion(String id) async {
    await _db.from('discussions').delete().eq('id', id);
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

  /// 현재 사용자의 참여 상태를 반환: 'host' / 'joined' / 'pending' / 'none'
  Future<String> myMembershipStatus(String discussionId) async {
    if (_uid.isEmpty) return 'none';
    final p = await _db
        .from('discussion_participants')
        .select('role, status')
        .eq('discussion_id', discussionId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (p != null && p['status'] == 'joined') {
      return (p['role'] == 'host') ? 'host' : 'joined';
    }
    final r = await _db
        .from('discussion_join_requests')
        .select('status')
        .eq('discussion_id', discussionId)
        .eq('user_id', _uid)
        .maybeSingle();
    if (r != null && r['status'] == 'pending') return 'pending';
    return 'none';
  }

  /// 호스트 승인이 필요한 모임에 가입 신청
  Future<void> requestJoin(String discussionId, {String? message}) async {
    await _db.from('discussion_join_requests').upsert({
      'discussion_id': discussionId,
      'user_id': _uid,
      'message': message,
      'status': 'pending',
    });
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

  // ---------- Meetings ----------
  Future<List<Map<String, dynamic>>> meetings(String discussionId) async {
    final rows = await _db
        .from('discussion_meetings')
        .select()
        .eq('discussion_id', discussionId)
        .order('scheduled_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> createMeeting({
    required String discussionId,
    required DateTime scheduledAt,
    String? bookId,
    String? moderatorId,
    String? location,
    String? onlineUrl,
  }) async {
    await _db.from('discussion_meetings').insert({
      'discussion_id': discussionId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'book_id': bookId,
      'moderator_id': moderatorId ?? _uid,
      'location': location,
      'online_url': onlineUrl,
    });
  }

  Future<void> deleteMeeting(String meetingId) async {
    await _db.from('discussion_meetings').delete().eq('id', meetingId);
  }

  // ---------- Attendance ----------
  Future<List<Map<String, dynamic>>> attendance(String meetingId) async {
    final rows = await _db
        .from('discussion_attendance')
        .select()
        .eq('meeting_id', meetingId);
    final records = (rows as List).cast<Map<String, dynamic>>();
    final nickMap = <String, String>{};
    for (final r in records) {
      final uid = r['user_id'] as String;
      if (!nickMap.containsKey(uid)) {
        final p = await _db
            .from('profiles')
            .select('nickname')
            .eq('id', uid)
            .maybeSingle();
        nickMap[uid] = (p?['nickname'] as String?) ?? '알 수 없음';
      }
    }
    return records.map((r) => {...r, 'nickname': nickMap[r['user_id']] ?? '알 수 없음'}).toList();
  }

  Future<void> checkIn(String meetingId, {String status = 'present'}) async {
    await _db.from('discussion_attendance').upsert({
      'meeting_id': meetingId,
      'user_id': _uid,
      'status': status,
    });
  }

  // ---------- Chat ----------
  Future<List<Map<String, dynamic>>> chatMessages(String discussionId, {int limit = 50}) async {
    final rows = await _db
        .from('discussion_chat')
        .select()
        .eq('discussion_id', discussionId)
        .order('created_at', ascending: false)
        .limit(limit);
    final messages = (rows as List).cast<Map<String, dynamic>>();
    // sender_id로 닉네임 조회
    final senderIds = messages.map((m) => m['sender_id'] as String).toSet();
    final nickMap = <String, String>{};
    for (final uid in senderIds) {
      final p = await _db
          .from('profiles')
          .select('nickname')
          .eq('id', uid)
          .maybeSingle();
      nickMap[uid] = (p?['nickname'] as String?) ?? '알 수 없음';
    }
    return messages.map((m) {
      return {
        ...m,
        'nickname': nickMap[m['sender_id']] ?? '알 수 없음',
      };
    }).toList();
  }

  Future<void> sendMessage(String discussionId, String content, {String? replyTo}) async {
    final data = <String, dynamic>{
      'discussion_id': discussionId,
      'sender_id': _uid,
      'content': content,
    };
    if (replyTo != null) data['reply_to'] = replyTo;
    await _db.from('discussion_chat').insert(data);
  }

  // ---------- Book Candidates & Voting ----------
  Future<List<Map<String, dynamic>>> bookCandidates(String discussionId) async {
    final rows = await _db
        .from('discussion_book_candidates')
        .select('*, books!book_id(title, author, cover_url), votes:discussion_votes(count)')
        .eq('discussion_id', discussionId)
        .eq('is_closed', false)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> suggestBook(String discussionId, String bookId) async {
    await _db.from('discussion_book_candidates').upsert({
      'discussion_id': discussionId,
      'book_id': bookId,
      'suggested_by': _uid,
    });
  }

  Future<void> vote(String candidateId) async {
    await _db.from('discussion_votes').upsert({
      'candidate_id': candidateId,
      'user_id': _uid,
    });
  }

  Future<void> unvote(String candidateId) async {
    await _db
        .from('discussion_votes')
        .delete()
        .eq('candidate_id', candidateId)
        .eq('user_id', _uid);
  }

  Future<List<Map<String, dynamic>>> myVotes(String discussionId) async {
    final candidates = await _db
        .from('discussion_book_candidates')
        .select('id')
        .eq('discussion_id', discussionId);
    final candidateIds = (candidates as List).map((c) => c['id'] as String).toList();
    if (candidateIds.isEmpty) return [];
    final rows = await _db
        .from('discussion_votes')
        .select()
        .eq('user_id', _uid)
        .inFilter('candidate_id', candidateIds);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ---------- Topics ----------
  Future<List<Map<String, dynamic>>> topics(String discussionId) async {
    final rows = await _db
        .from('discussion_topics')
        .select()
        .eq('discussion_id', discussionId)
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final nickMap = <String, String>{};
    for (final r in list) {
      final uid = r['author_id'] as String? ?? '';
      if (uid.isNotEmpty && !nickMap.containsKey(uid)) {
        final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
        nickMap[uid] = (p?['nickname'] as String?) ?? '알 수 없음';
      }
    }
    return list.map((r) => {...r, 'nickname': nickMap[r['author_id']] ?? '알 수 없음'}).toList();
  }

  Future<void> createTopic(String discussionId, String content) async {
    await _db.from('discussion_topics').insert({
      'discussion_id': discussionId,
      'author_id': _uid,
      'content': content,
    });
  }

  Future<void> deleteTopic(String topicId) async {
    await _db.from('discussion_topics').delete().eq('id', topicId);
  }

  // ---------- Quotes ----------
  Future<List<Map<String, dynamic>>> quotes(String discussionId) async {
    final rows = await _db
        .from('discussion_quotes')
        .select()
        .eq('discussion_id', discussionId)
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final nickMap = <String, String>{};
    for (final r in list) {
      final uid = r['author_id'] as String? ?? '';
      if (uid.isNotEmpty && !nickMap.containsKey(uid)) {
        final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
        nickMap[uid] = (p?['nickname'] as String?) ?? '알 수 없음';
      }
    }
    return list.map((r) => {...r, 'nickname': nickMap[r['author_id']] ?? '알 수 없음'}).toList();
  }

  Future<void> createQuote(String discussionId, String content, {int? pageNumber}) async {
    await _db.from('discussion_quotes').insert({
      'discussion_id': discussionId,
      'author_id': _uid,
      'content': content,
      'page_number': pageNumber,
    });
  }

  Future<void> deleteQuote(String quoteId) async {
    await _db.from('discussion_quotes').delete().eq('id', quoteId);
  }

  // ---------- Notes ----------
  Future<List<Map<String, dynamic>>> notes(String discussionId) async {
    final rows = await _db
        .from('discussion_notes')
        .select()
        .eq('discussion_id', discussionId)
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final nickMap = <String, String>{};
    for (final r in list) {
      final uid = r['author_id'] as String? ?? '';
      if (uid.isNotEmpty && !nickMap.containsKey(uid)) {
        final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
        nickMap[uid] = (p?['nickname'] as String?) ?? '알 수 없음';
      }
    }
    return list.map((r) => {...r, 'nickname': nickMap[r['author_id']] ?? '알 수 없음'}).toList();
  }

  Future<void> createNote(String discussionId, String content) async {
    await _db.from('discussion_notes').insert({
      'discussion_id': discussionId,
      'author_id': _uid,
      'content': content,
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _db.from('discussion_notes').delete().eq('id', noteId);
  }

  // ---------- Member Management ----------
  Future<List<Map<String, dynamic>>> memberList(String discussionId) async {
    final rows = await _db
        .from('discussion_participants')
        .select('user_id, role, status, joined_at')
        .eq('discussion_id', discussionId)
        .eq('status', 'joined')
        .order('joined_at');
    final list = <Map<String, dynamic>>[];
    for (final r in (rows as List)) {
      final uid = r['user_id'] as String;
      final p = await _db.from('profiles').select('nickname, region').eq('id', uid).maybeSingle();
      list.add({
        ...r as Map<String, dynamic>,
        'nickname': (p?['nickname'] as String?) ?? '알 수 없음',
        'region': p?['region'] as String?,
      });
    }
    return list;
  }

  Future<void> kickMember(String discussionId, String userId) async {
    await _db
        .from('discussion_participants')
        .update({'status': 'kicked'})
        .eq('discussion_id', discussionId)
        .eq('user_id', userId);
  }

  Future<void> changeRole(String discussionId, String userId, String role) async {
    await _db
        .from('discussion_participants')
        .update({'role': role})
        .eq('discussion_id', discussionId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> joinRequests(String discussionId) async {
    final rows = await _db
        .from('discussion_join_requests')
        .select()
        .eq('discussion_id', discussionId)
        .eq('status', 'pending')
        .order('created_at');
    final list = <Map<String, dynamic>>[];
    for (final r in (rows as List)) {
      final uid = r['user_id'] as String;
      final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
      list.add({...r as Map<String, dynamic>, 'nickname': (p?['nickname'] as String?) ?? '알 수 없음'});
    }
    return list;
  }

  Future<void> approveJoinRequest(String discussionId, String userId) async {
    await _db
        .from('discussion_join_requests')
        .update({'status': 'accepted'})
        .eq('discussion_id', discussionId)
        .eq('user_id', userId);
    await _db.from('discussion_participants').upsert({
      'discussion_id': discussionId,
      'user_id': userId,
      'status': 'joined',
      'role': 'member',
    });
  }

  Future<void> rejectJoinRequest(String discussionId, String userId) async {
    await _db
        .from('discussion_join_requests')
        .update({'status': 'rejected'})
        .eq('discussion_id', discussionId)
        .eq('user_id', userId);
  }

  // ---------- Moderator Rotation ----------
  Future<List<Map<String, dynamic>>> memberOrder(String discussionId) async {
    final rows = await _db
        .from('discussion_participants')
        .select('user_id')
        .eq('discussion_id', discussionId)
        .eq('status', 'joined')
        .order('joined_at');
    final list = <Map<String, dynamic>>[];
    for (final r in (rows as List)) {
      final uid = r['user_id'] as String;
      final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
      list.add({'user_id': uid, 'nickname': (p?['nickname'] as String?) ?? '알 수 없음'});
    }
    return list;
  }

  Future<String?> nextModeratorId(String discussionId) async {
    final members = await memberOrder(discussionId);
    if (members.isEmpty) return null;

    // 가장 최근 모임의 진행자 조회
    final lastMeeting = await _db
        .from('discussion_meetings')
        .select('moderator_id')
        .eq('discussion_id', discussionId)
        .order('scheduled_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastMeeting == null) return members.first['user_id'] as String;

    final lastModId = lastMeeting['moderator_id'] as String?;
    if (lastModId == null) return members.first['user_id'] as String;

    final idx = members.indexWhere((m) => m['user_id'] == lastModId);
    final nextIdx = (idx + 1) % members.length;
    return members[nextIdx]['user_id'] as String;
  }

  // ---------- Stats ----------
  Future<Map<String, dynamic>> discussionStats(String discussionId) async {
    final meetings = await _db
        .from('discussion_meetings')
        .select('id')
        .eq('discussion_id', discussionId);
    final membersRaw = await _db
        .from('discussion_participants')
        .select('user_id')
        .eq('discussion_id', discussionId)
        .eq('status', 'joined');
    // 닉네임 별도 조회
    final memberList = <Map<String, dynamic>>[];
    for (final m in (membersRaw as List)) {
      final uid = m['user_id'] as String;
      final p = await _db.from('profiles').select('nickname').eq('id', uid).maybeSingle();
      memberList.add({'user_id': uid, 'nickname': (p?['nickname'] as String?) ?? '알 수 없음'});
    }
    final completedBooks = await _db
        .from('discussion_books')
        .select()
        .eq('discussion_id', discussionId)
        .order('scheduled_at');
    // 책 정보 별도 조회
    final bookList = <Map<String, dynamic>>[];
    for (final b in (completedBooks as List)) {
      final bookId = b['book_id'] as String;
      final book = await _db.from('books').select('title, author, cover_url').eq('id', bookId).maybeSingle();
      bookList.add({...b as Map<String, dynamic>, 'books': book});
    }

    // 출석 통계
    final meetingIds = (meetings as List).map((m) => m['id'] as String).toList();
    final attendanceMap = <String, int>{};
    for (final mid in meetingIds) {
      final att = await _db
          .from('discussion_attendance')
          .select('user_id')
          .eq('meeting_id', mid);
      for (final a in (att as List)) {
        final uid = a['user_id'] as String;
        attendanceMap[uid] = (attendanceMap[uid] ?? 0) + 1;
      }
    }

    return {
      'meetingCount': meetingIds.length,
      'memberCount': memberList.length,
      'members': memberList,
      'books': bookList,
      'attendanceMap': attendanceMap,
    };
  }

  // ---------- Announcements ----------
  Future<List<Map<String, dynamic>>> announcements(String discussionId) async {
    final rows = await _db
        .from('discussion_announcements')
        .select()
        .eq('discussion_id', discussionId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> createAnnouncement(String discussionId, String title, {String? content, bool isPinned = false}) async {
    await _db.from('discussion_announcements').insert({
      'discussion_id': discussionId,
      'author_id': _uid,
      'title': title,
      'content': content,
      'is_pinned': isPinned,
    });
  }
}
