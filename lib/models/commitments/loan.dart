/// Whether a loan still has principal outstanding.
enum LoanStatus { pending, fullyPaid }

/// Repayment behavior used to describe a loan.
enum LoanType { revolving, oneTime, emiAmortizing }

/// A persisted loan and its current principal totals.
class LoanRecord {
  const LoanRecord({
    this.id,
    this.name = 'Loan',
    required this.totalAmountPaise,
    this.amountPaidPaise = 0,
    this.note = '',
    required this.startDate,
    this.endDate,
    this.status = LoanStatus.pending,
    required this.type,
    this.isEmi = false,
  });

  final int? id;
  final String name;
  final int totalAmountPaise;
  final int amountPaidPaise;
  final String note;
  final DateTime startDate;
  final DateTime? endDate;
  final LoanStatus status;
  final LoanType type;
  final bool isEmi;

  int get remainingPaise =>
      (totalAmountPaise - amountPaidPaise).clamp(0, totalAmountPaise);
  bool get isComplete => remainingPaise == 0;
}

/// One dated principal, interest and tax payment against a loan.
class LoanTrackingRecord {
  const LoanTrackingRecord({
    this.id,
    required this.loanId,
    required this.principalPaise,
    required this.interestPaise,
    this.gstPaise = 0,
    required this.date,
    this.isPaid = false,
  });

  final int? id;
  final int loanId;
  final int principalPaise;
  final int interestPaise;
  final int gstPaise;
  final DateTime date;
  final bool isPaid;
}
