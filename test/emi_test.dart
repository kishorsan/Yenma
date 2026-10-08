import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/data/commitments_data.dart';
import 'package:yenma/features/emi/emi_screen.dart';

import 'support/memory_repository.dart';

void main() {
  test(
    'GST is calculated on interest and paid principal completes an EMI',
    () async {
      final repository = MemoryRepository();
      final emiId = await repository.saveEmi(
        EmiRecord(
          name: 'Laptop',
          principalPaise: 100000,
          billingDay: 7,
          startDate: DateTime(2026, 10, 7),
        ),
      );

      await repository.saveEmiInstallment(
        emiId: emiId,
        principalPaise: 100000,
        interestPaise: 10000,
        date: DateTime(2026, 10, 7),
        isPaid: true,
      );

      final installment = (await repository.emiInstallments(emiId)).single;
      expect(installment.gstPaise, 1800);
      expect(installment.totalPaise, 111800);
      expect((await repository.emis()).single.isComplete, isTrue);
    },
  );

  testWidgets('records both an EMI and its monthly breakdown', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository();
    final controller = MoneyController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EmiScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No EMIs yet'), findsOneWidget);

    await tester.tap(find.text('Record EMI').last);
    await tester.pumpAndSettle();
    final emiFields = find.byType(TextFormField);
    await tester.enterText(emiFields.at(0), 'Phone');
    await tester.enterText(emiFields.at(1), '1000');
    await tester.enterText(emiFields.at(2), '99');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedEmis, hasLength(1));
    expect(find.text('Phone'), findsOneWidget);
    expect(find.textContaining('₹1,000.00 remaining'), findsOneWidget);

    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record monthly EMI'));
    await tester.pumpAndSettle();
    final paymentFields = find.byType(TextFormField);
    await tester.enterText(paymentFields.at(0), '250');
    await tester.enterText(paymentFields.at(1), '10');
    await tester.pump();
    expect(find.text('₹1.80'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedEmiInstallments, hasLength(1));
    expect(find.text('₹261.80'), findsOneWidget);
  });
}
