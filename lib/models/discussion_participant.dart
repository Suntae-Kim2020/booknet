/// 독서토론 참가자
class DiscussionParticipant {
  final String id;
  final String discussionId;
  final String userId;
  final String status; // 'joined' / 'left' / 'kicked'
  final DateTime joinedAt;

  const DiscussionParticipant({
    required this.id,
    required this.discussionId,
    required this.userId,
    this.status = 'joined',
    required this.joinedAt,
  });

  factory DiscussionParticipant.fromMap(Map<String, dynamic> m) =>
      DiscussionParticipant(
        id: m['id'] as String,
        discussionId: m['discussion_id'] as String,
        userId: m['user_id'] as String,
        status: m['status'] as String? ?? 'joined',
        joinedAt: DateTime.parse(m['joined_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'discussion_id': discussionId,
        'user_id': userId,
        'status': status,
        'joined_at': joinedAt.toIso8601String(),
      };
}
