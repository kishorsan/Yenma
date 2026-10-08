import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/features/transaction_detail.dart';

import 'support/transaction_dataset.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteMoneyRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma_recorded_test_');
    repository = SqliteMoneyRepository(
      factory: databaseFactoryFfi,
      path: '${directory.path}/test.db',
    );
    await repository.initialize();
    for (final entry in transactionDataset(DateTime(2026, 9, 1))) {
      await repository.save(entry);
    }
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  test('75 past/today/future records persist across month boundaries; existing splits are atomic', () async {
    final entries = [
      ...await repository.transactions(DateTime(2026, 8)),
      ...await repository.transactions(DateTime(2026, 9)),
    ];
    expect(entries, hasLength(75));
    expect(entries.map((e) => dateKey(e.date)).toSet(), hasLength(15));
    for (final entry in entries.where((e) => e.categoryId == 1)) {
      await repository.saveSharedExpense(
        entry,
        DebtDraft(
          person: 'Arun',
          title: entry.title,
          amountPaise: 25000,
          direction: DebtDirection.owedToMe,
          date: entry.date,
        ),
      );
    }
    final original = entries.firstWhere((e) => e.categoryId == 1);
    final changed = MoneyTransaction(
      id: original.id,
      title: 'Must roll back',
      amountPaise: 50000,
      kind: original.kind,
      categoryId: original.categoryId,
      date: original.date,
    );
    await expectLater(
      repository.saveSharedExpense(
        changed,
        DebtDraft(
          person: 'Meera',
          title: 'Too much',
          amountPaise: 30000,
          direction: DebtDirection.owedToMe,
          date: original.date,
        ),
      ),
      throwsA(isA<DebtValidationException>()),
    );
    expect(
      (await repository.transactionById(original.id!))!.title,
      original.title,
    );
    expect(await repository.people(), ['Arun']);
    await repository.close();
    await repository.initialize();
    expect(await repository.debts(), hasLength(15));
    expect([
      ...await repository.transactions(DateTime(2026, 8)),
      ...await repository.transactions(DateTime(2026, 9)),
    ], hasLength(75));
  });

  for (final edit in [false, true]) {
    testWidgets(
      'add debt to recorded transaction through ${edit ? 'edit' : 'details'} with SQLite',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = MoneyController(repository);
        await tester.runAsync(() => controller.initialize());
        final entries = await tester.runAsync(
          () => repository.transactions(DateTime(2026, 9)),
        );
        final entry = entries!.firstWhere((e) => e.categoryId == 1);
        await tester.pumpWidget(
          MaterialApp(
            home: TransactionDetail(controller: controller, transaction: entry),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(String label) async {
          final finder = find.text(label);
          await tester.scrollUntilVisible(
            finder,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tap(edit ? 'Edit transaction' : 'Add a friend’s share');
        if (edit) await tap('Split with a friend');
        final person = field(edit ? 'Friend’s name' : 'Person');
        await tester.scrollUntilVisible(
          person,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(person, 'Arun');
        await tap(edit ? 'Split equally' : 'Half of the unallocated amount');
        final save = find.text(edit ? 'Save transaction' : 'Save debt');
        await tester.scrollUntilVisible(
          save,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.runAsync(() async {
          await tester.tap(save);
          // Drain the native SQLite work started by the form before assertions.
          for (
            var attempt = 0;
            attempt < 100 && controller.debts.isEmpty;
            attempt++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        final debts = await tester.runAsync(repository.debts);
        expect(debts, hasLength(1));
        expect(debts!.single.transactionId, entry.id);
        expect(debts.single.amountPaise, 25000);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
