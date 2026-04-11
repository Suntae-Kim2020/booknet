/// 꾸러미 구매 요청
class PurchaseRequest {
  final String id;
  final String bundleId;
  final String buyerId;
  final List<String> selectedBookIds;
  final int totalPriceWon;
  final String deliveryMethod; // 'delivery' / 'in_person'
  final String status; // 'pending' / 'accepted' / 'rejected' / 'completed'
  final String? message;
  final DateTime createdAt;

  const PurchaseRequest({
    required this.id,
    required this.bundleId,
    required this.buyerId,
    required this.selectedBookIds,
    required this.totalPriceWon,
    this.deliveryMethod = 'delivery',
    this.status = 'pending',
    this.message,
    required this.createdAt,
  });

  factory PurchaseRequest.fromMap(Map<String, dynamic> m) => PurchaseRequest(
        id: m['id'] as String,
        bundleId: m['bundle_id'] as String,
        buyerId: m['buyer_id'] as String,
        selectedBookIds: ((m['selected_book_ids'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        totalPriceWon: (m['total_price_won'] as num).toInt(),
        deliveryMethod: m['delivery_method'] as String? ?? 'delivery',
        status: m['status'] as String? ?? 'pending',
        message: m['message'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'bundle_id': bundleId,
        'buyer_id': buyerId,
        'selected_book_ids': selectedBookIds,
        'total_price_won': totalPriceWon,
        'delivery_method': deliveryMethod,
        'status': status,
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };
}
