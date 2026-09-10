import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/domain/money.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteMoneyRepository repository;
  late String path;
  DebtDraft entry(String person) => DebtDraft(
    person: person,
    title: 'Meal',
    amountPaise: 25000,
    direction: DebtDirection.owedToMe,
    date: DateTime(2026, 1, 2),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma_people_test_');
    path = p.join(directory.path, 'people.db');
    repository = SqliteMoneyRepository(factory: databaseFactoryFfi, path: path);
    await repository.initialize();
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('saved names deduplicate and remain available after settlement, deletion and restart', () async {
    await repository.saveDebt(entry(' Arun   Kumar '));
    await repository.saveDebt(entry('arun kumar'));
    await repository.saveDebt(entry('Meera'));
    final records = await repository.debts();
    await repository.addRepayment(
      records.first.id,
      25000,
      DateTime(2026, 1, 2),
      '',
    );
    for (final debt in records) {
      await repository.deleteDebt(debt.id);
    }
    await repository.close();
    await repository.initialize();
    expect(await repository.people(), ['Arun Kumar', 'Meera']);
    expect(await repository.debts(), isEmpty);
  });

  test(
    'v2 upgrade backfills open and settled people without duplicating names',
    () async {
      await repository.saveDebt(entry('Arun'));
      await repository.saveDebt(entry(' ARUN '));
      await repository.saveDebt(entry('Meera'));
      await repository.addRepayment(
        (await repository.debts()).first.id,
        25000,
        DateTime(2026, 1, 2),
        'Settled',
      );
      // Construct the previous v2 schema in this isolated test database.
      await repository.debtDatabase.execute('DROP TABLE debt_people');
      await repository.debtDatabase.setVersion(2);
      await repository.close();
      await repository.initialize();
      expect(await repository.debtDatabase.getVersion(), 3);
      expect(await repository.people(), ['Arun', 'Meera']);
      expect(await repository.debts(), hasLength(3));
      expect((await repository.debts()).first.isSettled, isTrue);
    },
  );

  test('failed split does not save a person or an expense', () async {
    await expectLater(
      repository.saveSharedExpense(
        MoneyTransaction(
          title: 'Meal',
          amountPaise: 100,
          kind: TransactionKind.expense,
          categoryId: 1,
          date: DateTime(2026, 1, 2),
        ),
        entry('Not saved'),
      ),
      throwsA(isA<DebtValidationException>()),
    );
    expect(await repository.people(), isEmpty);
    expect(await repository.transactions(DateTime(2026, 1)), isEmpty);
  });
}
