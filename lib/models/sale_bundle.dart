import 'bundle_book.dart';

/// 판매 꾸러미 — 여러 권을 묶어 판매하는 단위
class SaleBundle {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String status; // listed, reserved, sold, hidden
  final DateTime createdAt;
  final List<BundleBook> books; // 개별 책 + 가격

  const SaleBundle({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.status = 'listed',
    required this.createdAt,
    this.books = const [],
  });

  int get totalPriceWon =>
      books.fold(0, (sum, b) => sum + b.priceWon);

  /// 상태 한글 표시
  String get statusLabel {
    switch (status) {
      case 'listed':
        return '판매중';
      case 'reserved':
        return '예약중';
      case 'sold':
        return '판매완료';
      case 'hidden':
        return '숨김';
      default:
        return status;
    }
  }

  factory SaleBundle.fromMap(Map<String, dynamic> m) => SaleBundle(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        status: m['status'] as String? ?? 'listed',
        createdAt: DateTime.parse(m['created_at'] as String),
        books: ((m['bundle_books'] as List?) ?? const [])
            .map((e) => BundleBook.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}
