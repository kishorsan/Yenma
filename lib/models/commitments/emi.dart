/// Identifies whether an EMI belongs to the user or is paid for another person.
enum EmiOwnership { mine, throughMe }

/// A persisted EMI agreement and its current principal progress.
class EmiRecord {
  const EmiRecord({
    this.id,
    required this.name,
    required this.principalPaise,
    this.paidPrincipalPaise = 0,
    this.processingFeePaise = 0,
    required this.billingDay,
    required this.startDate,
    this.endDate,
    this.note = '',
    this.ownership = EmiOwnership.mine,
  });

  final int? id;
  final String name;
  final int principalPaise;
  final int paidPrincipalPaise;
  final int processingFeePaise;
  final int billingDay;
  final DateTime startDate;
  final DateTime? endDate;
  final String note;
  final EmiOwnership ownership;

  int get remainingPaise =>
      (principalPaise - paidPrincipalPaise).clamp(0, principalPaise);
  bool get isComplete => remainingPaise == 0;
}

/// One calculated or recorded installment belonging to an EMI.
class EmiInstallment {
  const EmiInstallment({
    this.id,
    required this.emiId,
    required this.principalPaise,
    required this.interestPaise,
    required this.gstPaise,
    required this.date,
    required this.isPaid,
  });

  final int? id;
  final int emiId;
  final int principalPaise;
  final int interestPaise;
  final int gstPaise;
  final DateTime date;
  final bool isPaid;

  int get totalPaise => principalPaise + interestPaise + gstPaise;
}
