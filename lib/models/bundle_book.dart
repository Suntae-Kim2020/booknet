/// 꾸러미 내 개별 책 (가격 포함)
class BundleBook {
  final String id;
  final String bundleId;
  final String bookId;
  final int priceWon;

  const BundleBook({
    required this.id,
    required this.bundleId,
    required this.bookId,
    required this.priceWon,
  });

  factory BundleBook.fromMap(Map<String, dynamic> m) => BundleBook(
        id: m['id'] as String,
        bundleId: m['bundle_id'] as String,
        bookId: m['book_id'] as String,
        priceWon: (m['price_won'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'bundle_id': bundleId,
        'book_id': bookId,
        'price_won': priceWon,
      };
}
