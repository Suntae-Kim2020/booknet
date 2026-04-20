/// 책 도메인 모델
class Book {
  final String id;
  final String ownerId;
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String? coverUrl;
  final String? description;
  final DateTime? publishedAt;

  // 사용자 상태
  final bool isRead;
  final bool isForSale;
  final bool wantsDiscussion;
  final DateTime? readAt;
  final DateTime? deletedAt;

  const Book({
    required this.id,
    required this.ownerId,
    required this.isbn,
    required this.title,
    required this.author,
    required this.publisher,
    this.coverUrl,
    this.description,
    this.publishedAt,
    this.isRead = false,
    this.isForSale = false,
    this.wantsDiscussion = false,
    this.readAt,
    this.deletedAt,
  });

  Book copyWith({
    bool? isRead,
    bool? isForSale,
    bool? wantsDiscussion,
    DateTime? readAt,
  }) {
    return Book(
      id: id,
      ownerId: ownerId,
      isbn: isbn,
      title: title,
      author: author,
      publisher: publisher,
      coverUrl: coverUrl,
      description: description,
      publishedAt: publishedAt,
      isRead: isRead ?? this.isRead,
      isForSale: isForSale ?? this.isForSale,
      wantsDiscussion: wantsDiscussion ?? this.wantsDiscussion,
      readAt: readAt ?? this.readAt,
    );
  }

  factory Book.fromMap(Map<String, dynamic> m) => Book(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String? ?? '',
        isbn: m['isbn'] as String? ?? '',
        title: m['title'] as String? ?? '',
        author: m['author'] as String? ?? '',
        publisher: m['publisher'] as String? ?? '',
        coverUrl: m['cover_url'] as String?,
        description: m['description'] as String?,
        publishedAt: m['published_at'] != null
            ? DateTime.tryParse(m['published_at'] as String)
            : null,
        isRead: (m['is_read'] as bool?) ?? false,
        isForSale: (m['is_for_sale'] as bool?) ?? false,
        wantsDiscussion: (m['wants_discussion'] as bool?) ?? false,
        readAt: m['read_at'] != null
            ? DateTime.tryParse(m['read_at'] as String)
            : null,
        deletedAt: m['deleted_at'] != null
            ? DateTime.tryParse(m['deleted_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'isbn': isbn,
        'title': title,
        'author': author,
        'publisher': publisher,
        'cover_url': coverUrl,
        'description': description,
        'published_at': publishedAt?.toIso8601String(),
        'is_read': isRead,
        'is_for_sale': isForSale,
        'wants_discussion': wantsDiscussion,
        'read_at': readAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };
}
