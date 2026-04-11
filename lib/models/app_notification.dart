/// 앱 알림
class AppNotification {
  final String id;
  final String userId;
  final String type; // discussion_match / purchase_request / chat_message / bundle_sold
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final String channel; // in_app / kakao / sms / push
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.data,
    this.channel = 'in_app',
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        data: m['data'] as Map<String, dynamic>?,
        channel: m['channel'] as String? ?? 'in_app',
        isRead: (m['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'channel': channel,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
}
