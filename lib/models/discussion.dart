/// 독서 토론 모임
class Discussion {
  final String id;
  final String hostId;
  final String? bookId;
  final String title;
  final String? description;
  final String region;
  final bool isOnline;
  final String? onlineUrl;
  final DateTime scheduledAt;
  final int maxParticipants;
  final int currentParticipants;
  final String genderPolicy; // 'male_only' / 'female_only' / 'any'
  final int? minAge;
  final int? maxAge;
  final String status; // 'open' / 'closed' / 'completed'
  final String recurrence; // 'one_time' / 'weekly' / 'monthly'
  final String approvalMode; // 'auto' / 'manual'
  final String? rules;
  final String? currentBookId;
  final String? currentModeratorId;

  const Discussion({
    required this.id,
    required this.hostId,
    this.bookId,
    required this.title,
    this.description,
    required this.region,
    required this.isOnline,
    this.onlineUrl,
    required this.scheduledAt,
    this.maxParticipants = 10,
    this.currentParticipants = 1,
    this.genderPolicy = 'any',
    this.minAge,
    this.maxAge,
    this.status = 'open',
    this.recurrence = 'one_time',
    this.approvalMode = 'auto',
    this.rules,
    this.currentBookId,
    this.currentModeratorId,
  });

  factory Discussion.fromMap(Map<String, dynamic> m) => Discussion(
        id: m['id'] as String,
        hostId: m['host_id'] as String,
        bookId: m['book_id'] as String?,
        title: m['title'] as String,
        description: m['description'] as String?,
        region: m['region'] as String? ?? '',
        isOnline: (m['is_online'] as bool?) ?? false,
        onlineUrl: m['online_url'] as String?,
        scheduledAt: DateTime.parse(m['scheduled_at'] as String),
        maxParticipants: (m['max_participants'] as num?)?.toInt() ?? 10,
        currentParticipants:
            (m['current_participants'] as num?)?.toInt() ?? 1,
        genderPolicy: m['gender_policy'] as String? ?? 'any',
        minAge: (m['min_age'] as num?)?.toInt(),
        maxAge: (m['max_age'] as num?)?.toInt(),
        status: m['status'] as String? ?? 'open',
        recurrence: m['recurrence'] as String? ?? 'one_time',
        approvalMode: m['approval_mode'] as String? ?? 'auto',
        rules: m['rules'] as String?,
        currentBookId: m['current_book_id'] as String?,
        currentModeratorId: m['current_moderator_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'host_id': hostId,
        'book_id': bookId,
        'title': title,
        'description': description,
        'region': region,
        'is_online': isOnline,
        'online_url': onlineUrl,
        'scheduled_at': scheduledAt.toIso8601String(),
        'max_participants': maxParticipants,
        'current_participants': currentParticipants,
        'gender_policy': genderPolicy,
        'min_age': minAge,
        'max_age': maxAge,
        'status': status,
        'recurrence': recurrence,
        'approval_mode': approvalMode,
        'rules': rules,
        'current_book_id': currentBookId,
        'current_moderator_id': currentModeratorId,
      };

  String get genderLabel {
    switch (genderPolicy) {
      case 'male_only':
        return '남성만';
      case 'female_only':
        return '여성만';
      default:
        return '성별 무관';
    }
  }

  String get recurrenceLabel {
    switch (recurrence) {
      case 'weekly':
        return '매주';
      case 'monthly':
        return '매월';
      default:
        return '일회성';
    }
  }
}
