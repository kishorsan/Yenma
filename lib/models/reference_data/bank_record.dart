/// A bank or credit-card account tracked by the application.
class BankRecord {
  const BankRecord({
    this.id,
    required this.name,
    required this.code,
    this.isTracked = true,
    this.isCreditCard = false,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String code;
  final bool isTracked;
  final bool isCreditCard;
  final DateTime? createdAt;
}
