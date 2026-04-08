/// 판매 꾸러미 — 여러 권을 묶어 판매하는 단위
class SaleBundle {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final int priceWon;
  final List<String> bookIds;
  final String status; // listed, reserved, sold, hidden
  final DateTime createdAt;

  const SaleBundle({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.priceWon,
    required this.bookIds,
    this.status = 'listed',
    required this.createdAt,
  });

  factory SaleBundle.fromMap(Map<String, dynamic> m) => SaleBundle(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        priceWon: (m['price_won'] as num).toInt(),
        bookIds: ((m['book_ids'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        status: m['status'] as String? ?? 'listed',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'price_won': priceWon,
        'book_ids': bookIds,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}
