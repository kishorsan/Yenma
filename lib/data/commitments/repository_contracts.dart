import '../../models/commitments/emi.dart';
import '../../models/commitments/loan.dart';
import '../../models/commitments/subscription.dart';

/// Persistence operations required by the subscriptions feature.
abstract interface class SubscriptionRepository {
  /// Inserts or replaces a subscription and returns its database identifier.
  Future<int> saveSubscription(SubscriptionRecord value);

  /// Loads subscriptions, optionally filtering by active state.
  Future<List<SubscriptionRecord>> subscriptions({bool? active});
}

/// Persistence operations required by the EMI feature.
abstract interface class EmiRepository {
  /// Inserts or updates an EMI and returns its database identifier.
  Future<int> saveEmi(EmiRecord value);

  /// Loads all EMI agreements in display order.
  Future<List<EmiRecord>> emis();

  /// Loads the dated installment breakdown for [emiId].
  Future<List<EmiInstallment>> emiInstallments(int emiId);

  /// Stores an installment after applying the configured GST rate.
  Future<void> saveEmiInstallment({
    int? id,
    required int emiId,
    required int principalPaise,
    required int interestPaise,
    required DateTime date,
    required bool isPaid,
  });

  /// Reads the GST rate as basis points, where 1800 represents 18%.
  Future<int> loadGstBasisPoints();

  /// Persists the GST rate as basis points.
  Future<void> saveGstBasisPoints(int basisPoints);
}

/// Persistence operations required by the loans feature.
abstract interface class LoanRepository {
  /// Inserts or updates a loan and returns its database identifier.
  Future<int> saveLoan(LoanRecord value);

  /// Creates a loan and its complete calculated monthly schedule atomically.
  Future<int> saveLoanWithSchedule(LoanRecord value);

  /// Loads non-EMI loans in display order.
  Future<List<LoanRecord>> loans();

  /// Loads repayments recorded against [loanId].
  Future<List<LoanTrackingRecord>> loanPayments(int loanId);

  /// Validates and stores a repayment against a loan.
  Future<void> saveLoanPayment(LoanTrackingRecord value);
}
