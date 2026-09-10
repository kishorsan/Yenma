import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/money.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteMoneyRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma_test_');
    repository = SqliteMoneyRepository(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'money.db'),
    );
    await repository.initialize();
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  MoneyTransaction entry(
    String title,
    DateTime date, {
    int? id,
    int amount = 12345,
    int category = 1,
  }) => MoneyTransaction(
    id: id,
    title: title,
    amountPaise: amount,
    kind: TransactionKind.expense,
    categoryId: category,
    date: date,
    note: 'A note',
  );

  test(
    'schema seeds once, persists edits and preferences across restart, deletes',
    () async {
      expect(await repository.categories(), hasLength(13));
      await repository.save(entry('Lunch', DateTime(2026, 9, 10)));
      final id = (await repository.transactions(DateTime(2026, 9))).single.id!;
      await repository.save(
        entry('Dinner', DateTime(2026, 9, 11), id: id, amount: 23456),
      );
      await repository.saveTheme('dark');
      await repository.close();
      await repository.initialize();
      expect(await repository.categories(), hasLength(13));
      expect(await repository.loadTheme(), 'dark');
      final saved = (await repository.transactions(DateTime(2026, 9))).single;
      expect(saved.id, id);
      expect(saved.title, 'Dinner');
      expect(saved.amountPaise, 23456);
      expect(dateKey(saved.date), '2026-09-11');
      expect(saved.note, 'A note');
      await repository.delete(id);
      expect(await repository.transactions(DateTime(2026, 9)), isEmpty);
    },
  );

  test(
    'month boundaries, leap day, and same-date ordering are deterministic',
    () async {
      await repository.save(entry('January', DateTime(2024, 1, 31)));
      await repository.save(entry('Leap first', DateTime(2024, 2, 29)));
      await repository.save(entry('Leap second', DateTime(2024, 2, 29)));
      await repository.save(entry('March', DateTime(2024, 3)));
      expect(
        (await repository.transactions(DateTime(2024, 2))).map((t) => t.title),
        ['Leap second', 'Leap first'],
      );
      expect(await repository.transactions(DateTime(2024, 12)), isEmpty);
    },
  );

  test('invalid writes do not mutate existing records', () async {
    await expectLater(
      repository.save(entry(' ', DateTime(2026), amount: 100)),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(entry('Invalid amount', DateTime(2026), amount: -1)),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(entry('Unknown category', DateTime(2026), category: 999)),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(
        entry('Wrong category type', DateTime(2026), category: 10),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(entry('Missing ID', DateTime(2026), id: 999)),
      throwsStateError,
    );
    expect(await repository.transactions(DateTime(2026)), isEmpty);
  });
}
