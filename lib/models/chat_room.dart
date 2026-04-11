/// 흥정 채팅방
class ChatRoom {
  final String id;
  final String? purchaseRequestId;
  final List<String> participantIds;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const ChatRoom({
    required this.id,
    this.purchaseRequestId,
    required this.participantIds,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> m) => ChatRoom(
        id: m['id'] as String,
        purchaseRequestId: m['purchase_request_id'] as String?,
        participantIds: ((m['participant_ids'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        lastMessageAt: m['last_message_at'] != null
            ? DateTime.tryParse(m['last_message_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_request_id': purchaseRequestId,
        'participant_ids': participantIds,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
