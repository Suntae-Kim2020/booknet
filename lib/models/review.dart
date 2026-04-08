/// 책 한 줄 평
class Review {
  final String id;
  final String bookId;
  final String userId;
  final String content; // 한 줄 평
  final int? rating; // 1~5, optional
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.content,
    this.rating,
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        id: m['id'] as String,
        bookId: m['book_id'] as String,
        userId: m['user_id'] as String,
        content: m['content'] as String,
        rating: (m['rating'] as num?)?.toInt(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'user_id': userId,
        'content': content,
        'rating': rating,
        'created_at': createdAt.toIso8601String(),
      };
}
