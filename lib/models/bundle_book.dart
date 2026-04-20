/// 꾸러미 내 개별 책 (가격 포함 + 선택적 책 정보)
class BundleBook {
  final String id;
  final String bundleId;
  final String bookId;
  final int priceWon;
  final String? bookTitle;
  final String? bookAuthor;
  final String? bookPublisher;
  final String? bookCoverUrl;

  const BundleBook({
    required this.id,
    required this.bundleId,
    required this.bookId,
    required this.priceWon,
    this.bookTitle,
    this.bookAuthor,
    this.bookPublisher,
    this.bookCoverUrl,
  });

  factory BundleBook.fromMap(Map<String, dynamic> m) {
    final books = m['books'] as Map<String, dynamic>?;
    return BundleBook(
      id: m['id'] as String,
      bundleId: m['bundle_id'] as String,
      bookId: m['book_id'] as String,
      priceWon: (m['price_won'] as num).toInt(),
      bookTitle: books?['title'] as String?,
      bookAuthor: books?['author'] as String?,
      bookPublisher: books?['publisher'] as String?,
      bookCoverUrl: books?['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'bundle_id': bundleId,
        'book_id': bookId,
        'price_won': priceWon,
      };
}
