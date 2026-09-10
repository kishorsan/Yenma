import 'dart:io';
import 'dart:typed_data';

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
  final date = DateTime(2026, 1, 2);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma_debt_test_');
    path = p.join(directory.path, 'yenma.db');
    repository = SqliteMoneyRepository(factory: databaseFactoryFfi, path: path);
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  MoneyTransaction meal({
    int amount = 50000,
    int? id,
    TransactionKind kind = TransactionKind.expense,
  }) => MoneyTransaction(
    id: id,
    title: 'Meal',
    amountPaise: amount,
    kind: kind,
    categoryId: kind == TransactionKind.expense ? 1 : 10,
    date: date,
  );
  DebtDraft share({
    int? id,
    int? transactionId,
    String person = 'Arun',
    int amount = 25000,
    Uint8List? receipt,
    bool remove = false,
    DebtDirection direction = DebtDirection.owedToMe,
    DateTime? debtDate,
  }) => DebtDraft(
    id: id,
    transactionId: transactionId,
    person: person,
    title: 'Meal',
    amountPaise: amount,
    direction: direction,
    date: debtDate ?? date,
    note: 'Whenever you can',
    receipt: receipt,
    removeReceipt: remove,
  );
  final invalid = isA<DebtValidationException>();

  test('v1 upgrades without losing transactions, category IDs or preferences', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL, color INTEGER NOT NULL, kinds TEXT NOT NULL)',
          );
          await db.execute(
            "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, amount_paise INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'INR', kind TEXT NOT NULL, category_id INTEGER NOT NULL REFERENCES categories(id), date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', source TEXT NOT NULL DEFAULT 'MANUAL')",
          );
          await db.execute(
            'CREATE INDEX transactions_date_id ON transactions(date DESC, id DESC)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('categories', {
            'id': 1,
            'name': 'Food',
            'icon': 'restaurant',
            'color': 0xFFFF9F43,
            'kinds': 'expense',
          });
          await db.insert('transactions', meal(id: 42).toRow());
          await db.insert('settings', {'key': 'theme', 'value': 'dark'});
        },
      ),
    );
    await old.close();
    await repository.initialize();
    expect(await repository.debtDatabase.getVersion(), 2);
    expect((await repository.transactionById(42))!.amountPaise, 50000);
    expect((await repository.categories()).single.id, 1);
    expect(await repository.loadTheme(), 'dark');
    await repository.saveDebt(share(transactionId: 42));
    expect((await repository.debts()).single.remainingPaise, 25000);
  });

  test(
    'split is atomic, preserves full payment and enforces total shares',
    () async {
      await repository.initialize();
      await expectLater(
        repository.saveSharedExpense(meal(), share(amount: 60000)),
        throwsA(invalid),
      );
      expect(await repository.transactions(date), isEmpty);
      expect(await repository.debts(), isEmpty);
      await repository.saveSharedExpense(meal(), share());
      final payment = (await repository.transactions(date)).single;
      expect(payment.amountPaise, 50000);
      expect((await repository.debts()).single.transactionId, payment.id);
      await repository.saveDebt(
        share(transactionId: payment.id, person: 'Bala', amount: 20000),
      );
      await expectLater(
        repository.saveDebt(
          share(transactionId: payment.id, person: 'Extra', amount: 5001),
        ),
        throwsA(invalid),
      );
      await expectLater(
        repository.save(meal(id: payment.id, amount: 40000)),
        throwsA(invalid),
      );
      await expectLater(
        repository.save(meal(id: payment.id, kind: TransactionKind.income)),
        throwsA(invalid),
      );
      await expectLater(repository.delete(payment.id!), throwsA(invalid));
      expect(
        (await repository.transactionById(payment.id!))!.amountPaise,
        50000,
      );
      await expectLater(
        repository.saveDebt(share(transactionId: 999)),
        throwsA(invalid),
      );
    },
  );

  test('partial/full repayment and undo survive restart without duplicate transactions', () async {
    await repository.initialize();
    await repository.saveSharedExpense(meal(), share());
    var debt = (await repository.debts()).single;
    await repository.addRepayment(debt.id, 10000, date, 'UPI reference');
    expect((await repository.debts()).single.remainingPaise, 15000);
    await expectLater(
      repository.addRepayment(debt.id, 15001, date, ''),
      throwsA(invalid),
    );
    await expectLater(
      repository.saveDebt(
        share(id: debt.id, transactionId: debt.transactionId, amount: 9999),
      ),
      throwsA(invalid),
    );
    await repository.addRepayment(debt.id, 15000, date, 'Final');
    await repository.close();
    await repository.initialize();
    debt = (await repository.debts()).single;
    expect(debt.isSettled, isTrue);
    expect((await repository.repayments(debt.id)).first.note, 'Final');
    expect(await repository.transactions(date), hasLength(1));
    await repository.deleteRepayment(
      (await repository.repayments(debt.id)).first.id,
    );
    expect((await repository.debts()).single.remainingPaise, 15000);
  });

  test('concurrent repayments cannot overpay; invalid dates and amounts are rejected', () async {
    await repository.initialize();
    await repository.saveDebt(share());
    final debt = (await repository.debts()).single;
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        repository
            .addRepayment(debt.id, 20000, date, '')
            .then((_) => true)
            .catchError((Object _) => false),
    ]);
    expect(results.where((success) => success), hasLength(1));
    expect((await repository.debts()).single.remainingPaise, 5000);
    await expectLater(
      repository.addRepayment(debt.id, 0, date, ''),
      throwsA(invalid),
    );
    await expectLater(
      repository.addRepayment(debt.id, 1, DateTime(2025), ''),
      throwsA(invalid),
    );
    await expectLater(
      repository.addRepayment(
        debt.id,
        1,
        DateTime.now().add(const Duration(days: 1)),
        '',
      ),
      throwsA(invalid),
    );
    await expectLater(
      repository.saveDebt(
        share(id: debt.id, debtDate: date.add(const Duration(days: 1))),
      ),
      throwsA(invalid),
    );
  });

  test('large screenshot bytes are chunked, retained on edit and replace/remove cleanly', () async {
    await repository.initialize();
    final bytes = Uint8List.fromList(
      List.generate(3 * 1024 * 1024 + 7, (i) => i % 251),
    );
    await repository.saveDebt(share(receipt: bytes));
    final id = (await repository.debts()).single.id;
    await repository.close();
    await repository.initialize();
    expect(await repository.debtReceipt(id), orderedEquals(bytes));
    final chunks = await repository.debtDatabase.rawQuery(
      'SELECT MAX(length(bytes)) AS biggest FROM debt_receipt_chunks',
    );
    expect(chunks.single['biggest'], lessThanOrEqualTo(262144));
    await repository.saveDebt(share(id: id, person: 'Arun Kumar'));
    expect((await repository.debts()).single.note, 'Whenever you can');
    expect(await repository.debtReceipt(id), orderedEquals(bytes));
    final replacement = Uint8List.fromList([1, 2, 3]);
    await repository.saveDebt(share(id: id, receipt: replacement));
    expect(await repository.debtReceipt(id), orderedEquals(replacement));
    await repository.saveDebt(share(id: id, remove: true));
    expect((await repository.debts()).single.hasReceipt, isFalse);
    expect(await repository.debtReceipt(id), isNull);
    await expectLater(
      repository.saveDebt(share(receipt: Uint8List(maxReceiptBytes + 1))),
      throwsA(invalid),
    );
  });

  test(
    'deleting debt cascades receipt/history but keeps the original expense',
    () async {
      await repository.initialize();
      await repository.saveSharedExpense(
        meal(),
        share(receipt: Uint8List.fromList([1])),
      );
      final debt = (await repository.debts()).single;
      await repository.addRepayment(debt.id, 100, date, '');
      await repository.deleteDebt(debt.id);
      expect(await repository.debts(), isEmpty);
      expect(await repository.repayments(debt.id), isEmpty);
      expect(await repository.debtReceipt(debt.id), isNull);
      expect(await repository.transactionById(debt.transactionId!), isNotNull);
      await repository.delete(debt.transactionId!);
    },
  );

  test('standalone I-owe entries work and direction/link cannot be changed on edit', () async {
    await repository.initialize();
    await repository.saveDebt(share(direction: DebtDirection.iOwe));
    final debt = (await repository.debts()).single;
    expect(debt.direction, DebtDirection.iOwe);
    expect(debt.transactionId, isNull);
    expect(await repository.transactions(date), isEmpty);
    await expectLater(
      repository.saveDebt(share(id: debt.id)),
      throwsA(invalid),
    );
    await repository.addRepayment(debt.id, 25000, date, 'Paid back');
    expect((await repository.debts()).single.isSettled, isTrue);
  });
}
