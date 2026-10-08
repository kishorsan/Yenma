String monthYearKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

class PlanType {
  const PlanType({this.id, required this.name});

  final int? id;
  final String name;
}

class MoneyPlan {
  const MoneyPlan({
    this.id,
    this.planTypeId,
    required this.planName,
    required this.month,
    required this.plannedPaise,
    required this.remainingPaise,
    this.note = '',
    this.createdAt,
  });

  final int? id;
  final int? planTypeId;
  final String planName;
  final DateTime month;
  final int plannedPaise;
  final int remainingPaise;
  final String note;
  final DateTime? createdAt;
}
