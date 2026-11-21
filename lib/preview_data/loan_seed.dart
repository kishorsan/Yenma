import '../data/money_repository.dart';
import '../models/commitments/loan.dart';
import 'preview_dates.dart';

/// Creates amortizing, one-time and fully-paid loan examples.
Future<void> seedLoanPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  await _seedReportPersonalLoan(repository);

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

Future<void> _seedReportPersonalLoan(SqliteMoneyRepository repository) async {
  final firstDueDate = DateTime(2026, 11, 7);
  final loanId = await repository.saveLoan(
    LoanRecord(
      name: 'Personal loan · Report example',
      totalAmountPaise: 43000000,
      startDate: firstDueDate,
      endDate: DateTime(2030, 10, 7),
      note: '48-month statement example with a higher first instalment',
      type: LoanType.emiAmortizing,
      annualInterestBasisPoints: 1210,
      regularPaymentPaise: 1134500,
      installmentCount: 48,
      firstDueDate: firstDueDate,
    ),
  );
  const principalRupees = [
    7009,
    7079,
    7151,
    7223,
    7296,
    7369,
    7444,
    7519,
    7594,
    7671,
    7748,
    7827,
    7905,
    7985,
    8066,
    8147,
    8229,
    8312,
    8396,
    8481,
    8566,
    8653,
    8740,
    8828,
    8917,
    9007,
    9098,
    9190,
    9282,
    9376,
    9470,
    9566,
    9662,
    9760,
    9858,
    9958,
    10058,
    10159,
    10262,
    10365,
    10470,
    10576,
    10682,
    10790,
    10899,
    11009,
    11120,
    11228,
  ];
  const interestRupees = [
    6648,
    4266,
    4194,
    4122,
    4049,
    3976,
    3901,
    3826,
    3751,
    3674,
    3597,
    3518,
    3440,
    3360,
    3279,
    3198,
    3116,
    3033,
    2949,
    2864,
    2779,
    2692,
    2605,
    2517,
    2428,
    2338,
    2247,
    2155,
    2063,
    1969,
    1875,
    1779,
    1683,
    1585,
    1487,
    1387,
    1287,
    1186,
    1083,
    980,
    875,
    769,
    663,
    555,
    446,
    336,
    225,
    113,
  ];
  for (var index = 0; index < principalRupees.length; index++) {
    await repository.saveLoanPayment(
      LoanTrackingRecord(
        loanId: loanId,
        principalPaise: principalRupees[index] * 100,
        interestPaise: interestRupees[index] * 100,
        date: addPreviewMonths(firstDueDate, index),
      ),
    );
  }
}
