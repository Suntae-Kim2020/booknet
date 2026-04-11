/// 독서토론 관심 등록 (자동 알림 매칭용)
class DiscussionInterest {
  final String id;
  final String userId;
  final String bookId;
  final String? region;
  final bool isOnlineOk;
  final bool isOfflineOk;
  final DateTime createdAt;

  const DiscussionInterest({
    required this.id,
    required this.userId,
    required this.bookId,
    this.region,
    this.isOnlineOk = true,
    this.isOfflineOk = true,
    required this.createdAt,
  });

  factory DiscussionInterest.fromMap(Map<String, dynamic> m) =>
      DiscussionInterest(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        bookId: m['book_id'] as String,
        region: m['region'] as String?,
        isOnlineOk: (m['is_online_ok'] as bool?) ?? true,
        isOfflineOk: (m['is_offline_ok'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'book_id': bookId,
        'region': region,
        'is_online_ok': isOnlineOk,
        'is_offline_ok': isOfflineOk,
        'created_at': createdAt.toIso8601String(),
      };
}
