/// Database-facing representation of one normalized monthly plan row.
class MoneyPlanRecord {
  const MoneyPlanRecord({
    this.id,
    required this.planId,
    required this.plannedAmount,
    required this.remainingAmount,
    required this.monthYear,
    this.note = '',
    this.createdAt,
  });

  final int? id;
  final int planId;
  final int plannedAmount;
  final int remainingAmount;
  final String monthYear;
  final String note;
  final DateTime? createdAt;
}
