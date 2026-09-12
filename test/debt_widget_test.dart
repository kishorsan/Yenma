import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/data/receipt_source.dart';
import 'package:yenma/domain/debt.dart';

import 'support/memory_repository.dart';

class FakeReceiptSource implements ReceiptSource {
  Uint8List? image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  @override
  Future<Uint8List?> pick() async => image;
  @override
  Future<Uint8List?> recover() async => null;
}

void main() {
  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await reveal(tester, find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
    '500 meal split creates a 250 debt, with note and screenshot, then repays in parts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = MemoryRepository();
      final receipts = FakeReceiptSource();
      await tester.pumpWidget(
        YenmaApp(
          showWelcome: false,
          repository: repository,
          receipts: receipts,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add transaction'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Amount'), '500');
      await tester.enterText(field('Title'), 'Dinner split');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      await reveal(tester, field('Note (optional)'));
      await tester.enterText(field('Note (optional)'), 'Pay whenever you can');
      await tap(tester, 'Split with a friend');
      await reveal(tester, field('Friend’s name'));
      await tester.enterText(field('Friend’s name'), 'Arun');
      await tap(tester, 'Split equally');
      expect(
        find.text('Your share: ₹250.00 · Friend owes: ₹250.00'),
        findsOneWidget,
      );
      await tap(tester, 'Attach screenshot');
      await tap(tester, 'Save transaction');
      expect(repository.entries.single.amountPaise, 50000);
      var debt = (await repository.debts()).single;
      expect(debt.remainingPaise, 25000);
      expect(debt.note, 'Pay whenever you can');
      expect(debt.transactionId, repository.entries.single.id);
      expect(
        await repository.debtReceipt(debt.id),
        orderedEquals(receipts.image!),
      );
      await tester.tap(find.text('Debts'));
      await tester.pumpAndSettle();
      await tap(tester, 'Arun');
      await tap(tester, 'Dinner split');
      expect(find.text('Pay whenever you can'), findsOneWidget);
      await tap(tester, 'Record repayment');
      await tester.enterText(field('Repayment amount'), '100');
      await tap(tester, 'Save repayment');
      expect((await repository.debts()).single.remainingPaise, 15000);
      await tap(tester, 'Record repayment');
      await tap(tester, 'Use full remaining amount');
      await tap(tester, 'Save repayment');
      debt = (await repository.debts()).single;
      expect(debt.isSettled, isTrue);
      expect(repository.entries, hasLength(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Settled');
      await tap(tester, 'Arun');
      expect(find.text('Dinner split'), findsOneWidget);
    },
  );

  testWidgets(
    'standalone I owe supports canceled picker, validation and failed-save retention',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = MemoryRepository();
      final receipts = FakeReceiptSource()..image = null;
      await tester.pumpWidget(
        YenmaApp(
          showWelcome: false,
          repository: repository,
          receipts: receipts,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Debts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add debt'));
      await tester.pumpAndSettle();
      await tap(tester, 'Save debt');
      expect(find.text('Enter the person’s name'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I owe'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Person'), 'Bala');
      await tester.enterText(field('What was it for?'), 'Taxi share');
      await tester.enterText(field('Original amount owed'), '150');
      await tap(tester, 'Attach screenshot');
      expect(find.text('Remove screenshot'), findsNothing);
      repository.failSave = true;
      await tap(tester, 'Save debt');
      expect(
        find.text('Could not save this debt. Your details are still here.'),
        findsOneWidget,
      );
      expect(await repository.debts(), isEmpty);
      repository.failSave = false;
      await tap(tester, 'Save debt');
      expect((await repository.debts()).single.direction, DebtDirection.iOwe);
      expect((await repository.debts()).single.person, 'Bala');
      expect(repository.entries, isEmpty);
    },
  );
}
