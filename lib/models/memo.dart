/// 책 메모
class Memo {
  final String id;
  final String bookId;
  final String userId;
  final String content;
  final int? pageNumber;
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Memo({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.content,
    this.pageNumber,
    this.isShared = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Memo copyWith({
    String? content,
    int? pageNumber,
    bool? isShared,
  }) {
    return Memo(
      id: id,
      bookId: bookId,
      userId: userId,
      content: content ?? this.content,
      pageNumber: pageNumber ?? this.pageNumber,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory Memo.fromMap(Map<String, dynamic> m) => Memo(
        id: m['id'] as String,
        bookId: m['book_id'] as String,
        userId: m['user_id'] as String,
        content: m['content'] as String,
        pageNumber: (m['page_number'] as num?)?.toInt(),
        isShared: (m['is_shared'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'user_id': userId,
        'content': content,
        'page_number': pageNumber,
        'is_shared': isShared,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
