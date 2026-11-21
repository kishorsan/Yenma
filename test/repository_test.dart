import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/domain/monthly_plan.dart';
import 'package:yenma/domain/import_foundation.dart';
import 'package:yenma/domain/statement_import.dart';

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
      expect(await repository.categories(), hasLength(17));
      await repository.save(entry('Lunch', DateTime(2026, 9, 10)));
      final id = (await repository.transactions(DateTime(2026, 9))).single.id!;
      await repository.save(
        entry('Dinner', DateTime(2026, 9, 11), id: id, amount: 23456),
      );
      await repository.saveTheme('dark');
      await repository.close();
      await repository.initialize();
      expect(await repository.categories(), hasLength(17));
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

  test('imported financial instrument identity is persisted', () async {
    await repository.save(
      MoneyTransaction(
        title: 'Card purchase',
        amountPaise: 99900,
        kind: TransactionKind.expense,
        categoryId: 13,
        date: DateTime(2026, 10, 8),
        source: 'SMS',
        bankName: 'HDFC Bank',
        instrumentType: FinancialInstrumentType.creditCard,
        instrumentLast4: '4321',
        importRole: ImportedTransactionRole.cardPurchase,
      ),
    );

    final saved = (await repository.transactions(DateTime(2026, 10))).single;
    expect(saved.instrumentType, FinancialInstrumentType.creditCard);
    expect(saved.instrumentLast4, '4321');
    expect(saved.importRole, ImportedTransactionRole.cardPurchase);
    expect(saved.instrumentLabel, 'HDFC Bank •4321');
  });

  test(
    'import foundation retains inbox outcomes, accounts, provenance and cursor',
    () async {
      MoneyTransaction imported(String externalId) => MoneyTransaction(
        title: 'Corner Cafe',
        amountPaise: 12550,
        kind: TransactionKind.expense,
        categoryId: 13,
        date: DateTime(2026, 10, 15, 12, 30),
        source: 'SMS',
        bankName: 'HDFC Bank',
        instrumentType: FinancialInstrumentType.bankAccount,
        instrumentLast4: '1234',
        importRole: ImportedTransactionRole.accountDebit,
        externalId: externalId,
      );

      final first = await repository.importRecords([
        ImportRecord(
          source: 'sms',
          sourceItemId: 'message-1',
          rawPayload: 'HDFC\nINR 125.50 debited at Corner Cafe',
          receivedAt: DateTime(2026, 10, 15, 12, 31),
          transaction: imported('external-1'),
        ),
        ImportRecord(
          source: 'sms',
          sourceItemId: 'unsupported-1',
          rawPayload: 'HDFC\nYour statement is ready',
          receivedAt: DateTime(2026, 10, 15, 12, 32),
          rejectionReason: 'unsupported_message',
        ),
      ]);
      final duplicate = await repository.importRecords([
        ImportRecord(
          source: 'sms',
          sourceItemId: 'message-2',
          rawPayload: 'HDFC\nINR 125.50 debited at Corner Cafe',
          receivedAt: DateTime(2026, 10, 15, 12, 35),
          transaction: imported('external-2'),
        ),
      ]);
      final cursor = DateTime(2026, 10, 16, 8);
      await repository.saveImportCursor('sms', cursor);

      expect(first.imported, 1);
      expect(first.rejected, 1);
      expect(duplicate.duplicates, 1);
      expect(await repository.financialAccounts(), hasLength(1));
      expect(
        (await repository.importInbox()).map((item) => item.status),
        containsAll([
          ImportInboxStatus.imported,
          ImportInboxStatus.rejected,
          ImportInboxStatus.duplicate,
        ]),
      );
      expect(await repository.transactions(DateTime(2026, 10)), hasLength(1));

      await repository.close();
      await repository.initialize();
      expect(await repository.importCursor('sms'), cursor);
      expect(await repository.importInbox(), hasLength(3));
    },
  );

  test(
    'matching account debit and card payment produce a suggestion',
    () async {
      final result = await repository.importRecords([
        ImportRecord(
          source: 'sms',
          sourceItemId: 'account-side',
          rawPayload: 'Account debit for card bill',
          receivedAt: DateTime(2026, 10, 10),
          transaction: MoneyTransaction(
            title: 'Card bill',
            amountPaise: 485600,
            kind: TransactionKind.expense,
            categoryId: 13,
            date: DateTime(2026, 10, 10),
            source: 'SMS',
            bankName: 'HDFC Bank',
            instrumentType: FinancialInstrumentType.bankAccount,
            instrumentLast4: '1234',
            importRole: ImportedTransactionRole.accountDebit,
            externalId: 'account-external',
          ),
        ),
        ImportRecord(
          source: 'sms',
          sourceItemId: 'card-side',
          rawPayload: 'Card payment received',
          receivedAt: DateTime(2026, 10, 11),
          transaction: MoneyTransaction(
            title: 'Credit card payment',
            amountPaise: 485600,
            kind: TransactionKind.transfer,
            categoryId: 12,
            date: DateTime(2026, 10, 11),
            source: 'SMS',
            bankName: 'HDFC Credit Card',
            instrumentType: FinancialInstrumentType.creditCard,
            instrumentLast4: '4321',
            importRole: ImportedTransactionRole.cardPayment,
            externalId: 'card-external',
          ),
        ),
      ]);

      expect(result.reconciliationSuggestions, 1);
      final suggestion = (await repository.importReconciliations()).single;
      expect(suggestion.amountPaise, 485600);
      expect(suggestion.dateDistanceDays, 1);
      expect(suggestion.status, ReconciliationStatus.suggested);
      // Foundation only proposes the link; it does not silently edit the debit.
      expect(
        (await repository.transactions(DateTime(2026, 10)))
            .singleWhere(
              (item) => item.importRole == ImportedTransactionRole.accountDebit,
            )
            .kind,
        TransactionKind.expense,
      );
    },
  );

  test('statement import profiles persist and can be updated', () async {
    const profile = StatementImportProfile(
      name: 'Canara savings',
      sourceKey: 'canara-savings-1234',
      format: StatementFileFormat.csv,
      columns: {
        StatementField.sourceRecordId: 'Transaction ID',
        StatementField.transactionDate: 'Date',
        StatementField.description: 'Narration',
        StatementField.debitAmount: 'Debit',
        StatementField.creditAmount: 'Credit',
      },
      defaults: {
        StatementField.institution: 'Canara Bank',
        StatementField.instrumentType: 'Bank Account',
        StatementField.instrumentLast4: '1234',
        StatementField.currency: 'INR',
      },
    );
    final id = await repository.saveStatementImportProfile(profile);
    final saved = (await repository.statementImportProfiles()).single;
    expect(saved.id, id);
    expect(saved.columns[StatementField.debitAmount], 'Debit');

    await repository.saveStatementImportProfile(
      StatementImportProfile(
        id: id,
        name: saved.name,
        sourceKey: saved.sourceKey,
        format: saved.format,
        columns: saved.columns,
        defaults: saved.defaults,
        sheetName: 'Statement',
        headerRow: 5,
      ),
    );
    await repository.close();
    await repository.initialize();

    final updated = (await repository.statementImportProfiles()).single;
    expect(updated.sheetName, 'Statement');
    expect(updated.headerRow, 5);
  });

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

  test(
    'same-day transactions are ordered by time before insertion id',
    () async {
      await repository.save(entry('Evening', DateTime(2026, 9, 10, 18, 30)));
      await repository.save(entry('Morning', DateTime(2026, 9, 10, 8, 15)));
      expect(
        (await repository.transactions(DateTime(2026, 9))).map((t) => t.title),
        ['Evening', 'Morning'],
      );
    },
  );

  test('transaction range uses inclusive start and exclusive end', () async {
    await repository.save(entry('Before', DateTime(2026, 8, 31, 23, 59)));
    await repository.save(entry('At start', DateTime(2026, 9, 1)));
    await repository.save(entry('Today', DateTime(2026, 10, 8, 23, 59)));
    await repository.save(entry('At end', DateTime(2026, 10, 9)));

    final transactions = await repository.transactionsBetween(
      DateTime(2026, 9, 1),
      DateTime(2026, 10, 9),
    );

    expect(transactions.map((transaction) => transaction.title), [
      'Today',
      'At start',
    ]);
  });

  test('v6 date-only transactions migrate to noon', () async {
    await repository.save(entry('Legacy', DateTime(2026, 9, 10, 8)));
    await repository.debtDatabase.update('transactions', {
      'date': '2026-09-10',
    });
    await repository.debtDatabase.setVersion(6);
    await repository.close();
    await repository.initialize();

    expect(
      (await repository.transactions(DateTime(2026, 9))).single.date,
      DateTime(2026, 9, 10, 12),
    );
  });

  test('v7 databases receive the new categories', () async {
    await repository.debtDatabase.delete(
      'categories',
      where: 'id >= ?',
      whereArgs: [14],
    );
    await repository.debtDatabase.setVersion(7);
    await repository.close();
    await repository.initialize();

    final categories = await repository.categories();
    expect(
      categories
          .where((category) => category.id >= 14)
          .map((item) => item.name),
      ['Rent', 'Received', 'Wallet', 'Savings'],
    );
  });

  test('bulk categorization updates all selected records atomically', () async {
    await repository.save(entry('Lunch', DateTime(2026, 9, 10)));
    await repository.save(entry('Market', DateTime(2026, 9, 11)));
    final transactions = await repository.transactions(DateTime(2026, 9));
    await repository.bulkCategorize(transactions, 2);
    expect(
      (await repository.transactions(DateTime(2026, 9)))
          .map((transaction) => transaction.categoryId),
      everyElement(2),
    );
  });

  test(
    'plans reuse existing types and reference newly created types',
    () async {
      final month = DateTime(2026, 10);
      await repository.savePlan(
        MoneyPlan(
          planName: 'Savings',
          month: month,
          plannedPaise: 1000000,
          remainingPaise: 750000,
          note: 'Emergency fund',
        ),
      );
      await repository.savePlan(
        MoneyPlan(
          planName: 'Vacation',
          month: month,
          plannedPaise: 2500000,
          remainingPaise: 2000000,
        ),
      );

      final plans = await repository.plansForMonth(month);
      expect(plans, hasLength(2));
      final vacation = plans.singleWhere((plan) => plan.planName == 'Vacation');
      final typeRows = await repository.debtDatabase.query(
        'plan_type',
        where: 'plan = ?',
        whereArgs: ['Vacation'],
      );
      expect(typeRows, hasLength(1));
      expect(vacation.planTypeId, typeRows.single['id']);
      expect(vacation.remainingPaise, 2000000);
      expect(
        (await repository.planTypes()).map((type) => type.name),
        containsAll(['Savings', 'Vacation']),
      );
    },
  );

  test('v9 wide plans migrate into allocation and subtype rows', () async {
    final now = DateTime.now();
    final future = DateTime(now.year, now.month + 3);
    await repository.debtDatabase.execute('DROP TABLE monthly_plans');
    await repository.debtDatabase.execute('''CREATE TABLE monthly_plans (
      month TEXT PRIMARY KEY,
      salary_paise INTEGER NOT NULL,
      investment_paise INTEGER NOT NULL,
      savings_paise INTEGER NOT NULL,
      loans_paise INTEGER NOT NULL,
      daily_spend_paise INTEGER NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await repository.debtDatabase.insert('monthly_plans', {
      'month': dateKey(future),
      'salary_paise': 10000000,
      'investment_paise': 2000000,
      'savings_paise': 1000000,
      'loans_paise': 1500000,
      'daily_spend_paise': 3000000,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await repository.debtDatabase.setVersion(9);
    await repository.close();
    await repository.initialize();

    final rows = await repository.plansForMonth(future);
    expect(rows, hasLength(5));
    expect(rows.map((plan) => plan.planName), contains('Salary'));
    expect(
      rows.singleWhere((plan) => plan.planName == 'Salary').plannedPaise,
      10000000,
    );
    expect(rows.map((plan) => plan.planName), contains('Daily Spend'));
    expect(
      rows.every((plan) => plan.remainingPaise == plan.plannedPaise),
      isTrue,
    );
  });

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
