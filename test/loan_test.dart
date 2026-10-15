import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/data/commitments_data.dart';
import 'package:yenma/features/loans/loan_screen.dart';

import 'support/memory_repository.dart';

void main() {
  test(
    'paid principal updates the loan balance and completion state',
    () async {
      final repository = MemoryRepository();
      final loanId = await repository.saveLoan(
        LoanRecord(
          name: 'Bike loan',
          totalAmountPaise: 100000,
          startDate: DateTime(2026, 10, 1),
          type: LoanType.emiAmortizing,
        ),
      );

      await repository.saveLoanPayment(
        LoanTrackingRecord(
          loanId: loanId,
          principalPaise: 100000,
          interestPaise: 5000,
          date: DateTime(2026, 10, 8),
          isPaid: true,
        ),
      );

      final loan = (await repository.loans()).single;
      expect(loan.remainingPaise, 0);
      expect(loan.isComplete, isTrue);
      expect(
        (await repository.loanPayments(loanId)).single.interestPaise,
        5000,
      );
    },
  );

  testWidgets('records a loan and a paid repayment', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository();
    final controller = MoneyController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoanScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No loans yet'), findsOneWidget);

    await tester.tap(find.text('Record loan').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bike loan');
    await tester.enterText(fields.at(1), '1000');
    await tester.enterText(fields.at(2), '88.85');
    await tester.enterText(fields.at(3), '12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLoans, hasLength(1));
    expect(repository.savedLoanPayments, hasLength(12));
    expect(find.text('Bike loan'), findsOneWidget);
    expect(find.text('₹1,000.00'), findsWidgets);

    await tester.tap(find.text('Bike loan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    final paymentFields = find.byType(TextFormField);
    await tester.enterText(paymentFields.at(0), '250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLoanPayments, hasLength(13));
    expect(find.text('₹250.00'), findsWidgets);
    expect(find.text('₹750.00'), findsOneWidget);
  });

  test('generated schedule amortizes principal and reduces interest', () {
    final schedule = generateMonthlyLoanSchedule(
      loanId: 1,
      principalPaise: 43000000,
      annualInterestBasisPoints: 1210,
      installmentCount: 48,
      firstDueDate: DateTime(2026, 11, 7),
      regularPaymentPaise: 1134500,
    );

    expect(schedule, hasLength(48));
    expect(
      schedule.fold<int>(0, (sum, row) => sum + row.principalPaise),
      43000000,
    );
    expect(
      schedule.first.interestPaise,
      greaterThan(schedule.last.interestPaise),
    );
    expect(
      schedule.first.principalPaise,
      lessThan(schedule.last.principalPaise),
    );
    expect(schedule.last.date, DateTime(2030, 10, 7));
    expect(
      estimateAnnualInterestBasisPoints(
        principalPaise: 43000000,
        regularPaymentPaise: 1134500,
        installmentCount: 48,
      ),
      closeTo(1210, 1),
    );
  });
}
