/// 채팅 메시지
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String messageType; // 'text' / 'price_offer' / 'delivery_choice' / 'image'
  final Map<String, dynamic>? metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.metadata,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        roomId: m['room_id'] as String,
        senderId: m['sender_id'] as String,
        content: m['content'] as String,
        messageType: m['message_type'] as String? ?? 'text',
        metadata: m['metadata'] as Map<String, dynamic>?,
        readAt: m['read_at'] != null
            ? DateTime.tryParse(m['read_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'content': content,
        'message_type': messageType,
        'metadata': metadata,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
