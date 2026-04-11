import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat_message.dart';
import '../../models/chat_room.dart';
import '../../models/purchase_request.dart';

class ChatRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser?.id ?? '';

  // ---------- Purchase Requests ----------
  Future<PurchaseRequest> createPurchaseRequest(PurchaseRequest req) async {
    final row = await _db
        .from('purchase_requests')
        .insert(req.toMap())
        .select()
        .single();
    return PurchaseRequest.fromMap(row);
  }

  Future<List<PurchaseRequest>> requestsForBundle(String bundleId) async {
    final rows = await _db
        .from('purchase_requests')
        .select()
        .eq('bundle_id', bundleId)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => PurchaseRequest.fromMap(e)).toList();
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    await _db
        .from('purchase_requests')
        .update({'status': status})
        .eq('id', requestId);
  }

  // ---------- Chat Rooms ----------
  Future<ChatRoom> createChatRoom({
    required String purchaseRequestId,
    required String otherUserId,
  }) async {
    final row = await _db.from('chat_rooms').insert({
      'purchase_request_id': purchaseRequestId,
      'participant_ids': [_uid, otherUserId],
    }).select().single();
    return ChatRoom.fromMap(row);
  }

  Future<List<ChatRoom>> myChatRooms() async {
    final rows = await _db
        .from('chat_rooms')
        .select()
        .contains('participant_ids', [_uid])
        .order('last_message_at', ascending: false);
    return (rows as List).map((e) => ChatRoom.fromMap(e)).toList();
  }

  // ---------- Messages ----------
  Future<List<ChatMessage>> messages(String roomId, {int limit = 50}) async {
    final rows = await _db
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final row = await _db.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': _uid,
      'content': content,
      'message_type': messageType,
      'metadata': metadata,
    }).select().single();
    // 마지막 메시지 시간 업데이트
    await _db
        .from('chat_rooms')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', roomId);
    return ChatMessage.fromMap(row);
  }

  Future<void> markMessagesRead(String roomId) async {
    await _db
        .from('chat_messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('room_id', roomId)
        .neq('sender_id', _uid)
        .isFilter('read_at', null);
  }

  /// Supabase Realtime 채널 구독
  RealtimeChannel subscribeToRoom(
    String roomId,
    void Function(ChatMessage) onMessage,
  ) {
    return _db
        .channel('chat:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            onMessage(ChatMessage.fromMap(payload.newRecord));
          },
        )
        .subscribe();
  }
}
