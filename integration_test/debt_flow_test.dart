import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/domain/money.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> tapWhenVisible(WidgetTester tester, String label) async {
    final target = find.text(label);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (target.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(target.hitTestable());
        await tester.pumpAndSettle();
        return;
      }
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }
    fail('Could not reach $label');
  }

  testWidgets(
    'native SQLite split, large attachment, restart and repayment screen',
    (tester) async {
      // Dedicated test database. Never open or erase the user's yenma.db.
      final path = p.join(
        await getDatabasesPath(),
        'yenma-debt-device-test.db',
      );
      await deleteDatabase(path);
      final repository = SqliteMoneyRepository(path: path);
      addTearDown(() async {
        await repository.close();
        await deleteDatabase(path);
      });
      await repository.initialize();
      final date = calendarDate(DateTime.now());
      final large = Uint8List.fromList(
        List.generate(3 * 1024 * 1024 + 7, (index) => index % 251),
      );
      await repository.saveSharedExpense(
        MoneyTransaction(
          title: 'Device test meal',
          amountPaise: 50000,
          kind: TransactionKind.expense,
          categoryId: 1,
          date: date,
        ),
        DebtDraft(
          person: 'Test friend',
          title: 'Device test meal',
          amountPaise: 25000,
          direction: DebtDirection.owedToMe,
          date: date,
          note: 'UPI split test',
          receipt: large,
        ),
      );
      var debt = (await repository.debts()).single;
      await repository.close();
      await repository.initialize();
      expect(await repository.debtReceipt(debt.id), orderedEquals(large));
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await repository.saveDebt(
        DebtDraft(
          id: debt.id,
          transactionId: debt.transactionId,
          person: debt.person,
          title: debt.title,
          amountPaise: debt.amountPaise,
          direction: debt.direction,
          date: date,
          note: debt.note,
          receipt: png,
        ),
      );
      await repository.addRepayment(
        debt.id,
        10000,
        date,
        'First UPI repayment',
      );
      await tester.pumpWidget(YenmaApp(repository: repository));
      await tester.pumpAndSettle();
      // Platform database futures can complete between frames on an emulator.
      for (
        var i = 0;
        i < 50 &&
            find.text('Your money,\na little clearer.').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Debts'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Device test meal'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Device test meal'));
      await tester.pumpAndSettle();
      expect(find.text('UPI split test'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Record repayment'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tapWhenVisible(tester, 'Record repayment');
      await tapWhenVisible(tester, 'Use full remaining amount');
      await tester.scrollUntilVisible(
        find.text('Save repayment'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tapWhenVisible(tester, 'Save repayment');
      for (var attempt = 0; attempt < 50; attempt++) {
        if ((await repository.debts()).single.isSettled) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      debt = (await repository.debts()).single;
      expect(debt.isSettled, isTrue);
      expect(await repository.transactions(date), hasLength(1));
      expect(await repository.repayments(debt.id), hasLength(2));
      expect(await repository.debtReceipt(debt.id), orderedEquals(png));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
