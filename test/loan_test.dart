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
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedLoans, hasLength(1));
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

    expect(repository.savedLoanPayments, hasLength(1));
    expect(find.text('₹250.00'), findsWidgets);
    expect(find.text('₹750.00'), findsOneWidget);
  });
}
