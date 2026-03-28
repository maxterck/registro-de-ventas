class Sale {
  final String id;
  final String storeId;
  final String? productId;
  final String productNameSnapshot;
  final double amount;
  final String paymentMethod;
  final String? customerName;
  final bool isDebt;
  final String createdByKey;
  final DateTime timestamp;

  Sale({
    required this.id,
    required this.storeId,
    this.productId,
    required this.productNameSnapshot,
    required this.amount,
    required this.paymentMethod,
    this.customerName,
    required this.isDebt,
    required this.createdByKey,
    required this.timestamp,
  });
}
