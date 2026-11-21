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
    this.annualInterestBasisPoints,
    this.regularPaymentPaise,
    this.installmentCount,
    this.firstDueDate,
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

  /// Nominal annual rate where 1210 represents 12.10%.
  final int? annualInterestBasisPoints;
  final int? regularPaymentPaise;
  final int? installmentCount;
  final DateTime? firstDueDate;

  int get remainingPaise =>
      (totalAmountPaise - amountPaidPaise).clamp(0, totalAmountPaise);
  bool get isComplete => remainingPaise == 0;
  bool get hasGeneratedSchedule =>
      type == LoanType.emiAmortizing &&
      annualInterestBasisPoints != null &&
      regularPaymentPaise != null &&
      installmentCount != null &&
      firstDueDate != null;
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

  int get totalPaise => principalPaise + interestPaise + gstPaise;
}

/// Calculates a fixed-rate monthly reducing-balance repayment schedule.
///
/// Money is rounded to the nearest paise and the final row absorbs any
/// remaining rounding difference, so scheduled principal always equals the
/// financed amount.
List<LoanTrackingRecord> generateMonthlyLoanSchedule({
  required int loanId,
  required int principalPaise,
  required int annualInterestBasisPoints,
  required int installmentCount,
  required DateTime firstDueDate,
  int? regularPaymentPaise,
}) {
  if (principalPaise <= 0 ||
      annualInterestBasisPoints < 0 ||
      installmentCount <= 0) {
    throw ArgumentError('Invalid amortizing loan terms');
  }

  final monthlyRate = annualInterestBasisPoints / 120000;
  final calculatedPayment = monthlyRate == 0
      ? (principalPaise / installmentCount).round()
      : _paymentForRate(principalPaise, monthlyRate, installmentCount).round();
  final regularPayment = regularPaymentPaise ?? calculatedPayment;
  if (regularPayment <= 0) throw ArgumentError('Invalid monthly payment');
  var balance = principalPaise;
  return List.generate(installmentCount, (index) {
    final interest = (balance * monthlyRate).round();
    final principal = index == installmentCount - 1
        ? balance
        : (regularPayment - interest).clamp(0, balance);
    balance -= principal;
    return LoanTrackingRecord(
      loanId: loanId,
      principalPaise: principal,
      interestPaise: interest,
      date: _addMonths(firstDueDate, index),
    );
  });
}

/// Derives a nominal annual rate from the financed amount, regular payment,
/// and number of monthly instalments.
int estimateAnnualInterestBasisPoints({
  required int principalPaise,
  required int regularPaymentPaise,
  required int installmentCount,
}) {
  if (principalPaise <= 0 ||
      regularPaymentPaise <= 0 ||
      installmentCount <= 0 ||
      regularPaymentPaise * installmentCount < principalPaise) {
    throw ArgumentError('Payment cannot repay this principal');
  }
  final interestFreePayment = principalPaise / installmentCount;
  if (regularPaymentPaise <= interestFreePayment) return 0;
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 100; i++) {
    final rate = (low + high) / 2;
    final payment = _paymentForRate(principalPaise, rate, installmentCount);
    if (payment > regularPaymentPaise) {
      high = rate;
    } else {
      low = rate;
    }
  }
  return (((low + high) / 2) * 12 * 10000).round();
}

double _paymentForRate(int principalPaise, double rate, int count) =>
    principalPaise * rate * _pow(1 + rate, count) / (_pow(1 + rate, count) - 1);

double _pow(double value, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= value;
  }
  return result;
}

DateTime _addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, date.day.clamp(1, lastDay));
}
