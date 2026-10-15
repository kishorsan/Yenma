import '../data/money_repository.dart';
import '../models/commitments/loan.dart';
import 'preview_dates.dart';

/// Creates amortizing, one-time and fully-paid loan examples.
Future<void> seedLoanPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final educationLoanId = await repository.saveLoan(
    LoanRecord(
      name: 'Education loan',
      totalAmountPaise: 45000000,
      startDate: addPreviewMonths(anchor, -10),
      endDate: addPreviewMonths(anchor, 26),
      note: 'Postgraduate course loan',
      type: LoanType.emiAmortizing,
    ),
  );
  for (final payment in [
    LoanTrackingRecord(
      loanId: educationLoanId,
      principalPaise: 3000000,
      interestPaise: 420000,
      gstPaise: 75600,
      date: anchor.subtract(const Duration(days: 45)),
      isPaid: true,
    ),
    LoanTrackingRecord(
      loanId: educationLoanId,
      principalPaise: 3200000,
      interestPaise: 395000,
      gstPaise: 71100,
      date: anchor.subtract(const Duration(days: 15)),
      isPaid: true,
    ),
  ]) {
    await repository.saveLoanPayment(payment);
  }

  final familyLoanId = await repository.saveLoan(
    LoanRecord(
      name: 'Family emergency loan',
      totalAmountPaise: 10000000,
      startDate: addPreviewMonths(anchor, -5),
      endDate: addPreviewMonths(anchor, 7),
      note: 'Interest-free family loan',
      type: LoanType.oneTime,
    ),
  );
  await repository.saveLoanPayment(
    LoanTrackingRecord(
      loanId: familyLoanId,
      principalPaise: 2500000,
      interestPaise: 0,
      date: anchor.subtract(const Duration(days: 28)),
      isPaid: true,
    ),
  );

  final completedLoanId = await repository.saveLoan(
    LoanRecord(
      name: 'Cleared appliance loan',
      totalAmountPaise: 1200000,
      startDate: addPreviewMonths(anchor, -8),
      endDate: anchor,
      note: 'Completed loan example',
      type: LoanType.oneTime,
    ),
  );
  await repository.saveLoanPayment(
    LoanTrackingRecord(
      loanId: completedLoanId,
      principalPaise: 1200000,
      interestPaise: 0,
      date: anchor.subtract(const Duration(days: 3)),
      isPaid: true,
    ),
  );
}
