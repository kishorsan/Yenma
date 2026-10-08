import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/domain/money.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('Cards separates a credit card from its bank account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final repository = MemoryRepository();
    await repository.save(
      MoneyTransaction(
        title: 'ZOMATO LIMITED',
        amountPaise: 21941,
        kind: TransactionKind.expense,
        categoryId: 13,
        date: now,
        source: 'SMS',
        bankName: 'HDFC Credit Card',
        instrumentType: FinancialInstrumentType.creditCard,
        instrumentLast4: '4321',
        importRole: ImportedTransactionRole.cardPurchase,
      ),
    );
    await repository.save(
      MoneyTransaction(
        title: 'SANGEETHA K P',
        amountPaise: 500000,
        kind: TransactionKind.expense,
        categoryId: 13,
        date: now,
        source: 'SMS',
        bankName: 'HDFC Credit Card',
        instrumentType: FinancialInstrumentType.bankAccount,
        instrumentLast4: '1234',
        importRole: ImportedTransactionRole.accountDebit,
      ),
    );
    await repository.save(
      MoneyTransaction(
        title: 'Credit card payment',
        amountPaise: 485600,
        kind: TransactionKind.transfer,
        categoryId: 12,
        date: now,
        source: 'SMS',
        bankName: 'HDFC Bank',
        instrumentType: FinancialInstrumentType.creditCard,
        instrumentLast4: '4321',
        importRole: ImportedTransactionRole.cardPayment,
      ),
    );

    await tester.pumpWidget(
      YenmaApp(repository: repository, showWelcome: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();

    expect(find.text('HDFC Credit Card •4321'), findsOneWidget);
    expect(find.text('2 transactions'), findsOneWidget);
    expect(find.text(formatMoney(21941)), findsNWidgets(2));
    expect(find.text('ZOMATO LIMITED'), findsOneWidget);
    expect(find.text('Credit card payment'), findsOneWidget);
    expect(find.text('SANGEETHA K P'), findsNothing);
  });
}
