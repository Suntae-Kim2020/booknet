/// 독서 토론 모임
class Discussion {
  final String id;
  final String hostId;
  final String bookId;
  final String title;
  final String? description;
  final String region; // 시/도, 시/군/구
  final bool isOnline;
  final DateTime scheduledAt;
  final int maxParticipants;
  final int currentParticipants;

  const Discussion({
    required this.id,
    required this.hostId,
    required this.bookId,
    required this.title,
    this.description,
    required this.region,
    required this.isOnline,
    required this.scheduledAt,
    this.maxParticipants = 10,
    this.currentParticipants = 1,
  });

  factory Discussion.fromMap(Map<String, dynamic> m) => Discussion(
        id: m['id'] as String,
        hostId: m['host_id'] as String,
        bookId: m['book_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        region: m['region'] as String? ?? '',
        isOnline: (m['is_online'] as bool?) ?? false,
        scheduledAt: DateTime.parse(m['scheduled_at'] as String),
        maxParticipants: (m['max_participants'] as num?)?.toInt() ?? 10,
        currentParticipants:
            (m['current_participants'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'host_id': hostId,
        'book_id': bookId,
        'title': title,
        'description': description,
        'region': region,
        'is_online': isOnline,
        'scheduled_at': scheduledAt.toIso8601String(),
        'max_participants': maxParticipants,
        'current_participants': currentParticipants,
      };
}
