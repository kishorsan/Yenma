import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'dart:typed_data';

import '../domain/money.dart';
import '../domain/debt.dart';
import '../domain/monthly_plan.dart';
import '../domain/split.dart';
import 'application_support_data.dart';
import 'commitments_data.dart';
import 'yenma_schema.dart';
import 'debt_repository.dart';
import 'planning_data.dart';
import 'reference_data.dart';
import 'splitting_data.dart';

abstract interface class MoneyRepository
    implements DebtRepository, SplitRepository, SubscriptionRepository {
  Future<void> initialize();
  Future<List<MoneyCategory>> categories();
  Future<List<MoneyTransaction>> transactions(DateTime month);
  Future<void> save(MoneyTransaction transaction);
  Future<List<MoneyPlan>> plansForMonth(DateTime month);
  Future<List<PlanType>> planTypes();
  Future<void> savePlan(MoneyPlan plan);
  Future<void> bulkCategorize(
    List<MoneyTransaction> transactions,
    int categoryId,
  );
  Future<int> importTransactions(List<MoneyTransaction> transactions);
  Future<int?> categoryForRecipient(String recipientKey);
  Future<void> saveRecipientCategory(String recipientKey, int categoryId);
  Future<void> saveTransactionReceipt(int transactionId, Uint8List bytes);
  Future<Uint8List?> transactionReceipt(int transactionId);
  Future<void> deleteTransactionReceipt(int transactionId);
  Future<bool> wasSyncedOn(DateTime date);
  Future<void> markSynced(DateTime date);
  Future<DateTime?> lastSmsSyncAt();
  Future<void> recordSmsSync({
    required DateTime completedAt,
    required int imported,
    required bool automatic,
  });
  Future<void> delete(int id);
  Future<String> loadTheme();
  Future<void> saveTheme(String theme);
  Future<bool> loadSmsConsent();
  Future<void> saveSmsConsent(bool granted);
  Future<bool> loadInitialSmsSyncComplete();
  Future<void> saveInitialSmsSyncComplete();
  Future<void> close();
}

class SqliteMoneyRepository
    with SqliteDebtOperations, SqliteSplitOperations
    implements MoneyRepository {
  SqliteMoneyRepository({DatabaseFactory? factory, this._path})
    : _factory = factory ?? databaseFactory;
  final DatabaseFactory _factory;
  final String? _path;
  Database? _database;
  Database get _db => _database!;
  @override
  Database get debtDatabase => _db;
  @override
  Database get splitDatabase => _db;

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final path = _path ?? p.join(await _factory.getDatabasesPath(), 'yenma.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 14,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createMoneySchema(db);
          await createDebtSchema(db);
          await createPeopleSchema(db);
          await createStructuredDataSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await createDebtSchema(db);
          if (oldVersion < 3) await createPeopleSchema(db);
          if (oldVersion < 4) {
            await _addColumnIfMissing(db, 'transactions', 'bank_name', 'TEXT');
            await _addColumnIfMissing(
              db,
              'transactions',
              'external_id',
              'TEXT',
            );
            await _addColumnIfMissing(
              db,
              'transactions',
              'recipient_key',
              'TEXT',
            );
            await _createTransactionsTable(db);
            await _createRecipientCategoriesTable(db);
          }
          if (oldVersion < 5) {
            await _addColumnIfMissing(
              db,
              'transactions',
              'has_receipt',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await _createTransactionReceiptChunksTable(db);
            // Move legacy linked debt bills to their parent transaction without
            // dropping the old chunks, so existing debt history remains readable.
            await db.execute('''INSERT OR IGNORE INTO transaction_receipt_chunks
              (transaction_id, chunk_index, bytes)
              SELECT d.transaction_id, c.chunk_index, c.bytes
              FROM debts d JOIN debt_receipt_chunks c ON c.debt_id = d.id
              WHERE d.transaction_id IS NOT NULL''');
            await db.execute(
              '''UPDATE transactions SET has_receipt = 1
              WHERE id IN (SELECT DISTINCT transaction_id FROM debts
                           WHERE transaction_id IS NOT NULL AND has_receipt = 1)''',
            );
          }
          if (oldVersion < 6) {
            await _createSmsSyncLogTable(db);
          }
          if (oldVersion < 7) {
            await db.execute(
              "UPDATE transactions SET date = date || 'T12:00:00.000' "
              "WHERE instr(date, 'T') = 0 AND instr(date, ' ') = 0",
            );
          }
          if (oldVersion < 8) {
            await _seedDefaultCategories(db);
          }
          if (oldVersion < 9) {
            await _createMonthlyPlansTable(db);
          } else if (oldVersion < 10) {
            await _migrateMonthlyPlansV10(db);
          }
          if (oldVersion < 11) {
            await createStructuredDataSchema(db);
          }
          if (oldVersion < 12) {
            await _addColumnIfMissing(
              db,
              'money_plans',
              'remaining_amount',
              'INTEGER NOT NULL DEFAULT 0 CHECK(remaining_amount >= 0 AND remaining_amount <= planned_amount)',
            );
            await db.execute(
              'UPDATE money_plans SET remaining_amount = planned_amount',
            );
          }
          if (oldVersion < 13) await createSplittingSchema(db);
          if (oldVersion < 14) {
            await _addColumnIfMissing(
              db,
              'subscriptions',
              'billing_month',
              'INTEGER NOT NULL DEFAULT 1 CHECK(billing_month BETWEEN 1 AND 12)',
            );
          }
        },
      ),
    );
  }

  ReferenceDataRepository get referenceData => ReferenceDataRepository(_db);
  PlanningRepository get planning => PlanningRepository(_db);
  SplittingRepository get splitting => SplittingRepository(_db);
  CommitmentsRepository get commitments => CommitmentsRepository(_db);
  ApplicationSupportRepository get applicationSupport =>
      ApplicationSupportRepository(_db);

  @override
  Future<int> saveSubscription(SubscriptionRecord value) =>
      commitments.saveSubscription(value);

  @override
  Future<List<SubscriptionRecord>> subscriptions({bool? active}) =>
      commitments.subscriptions(active: active);

  static Future<void> _createMoneySchema(DatabaseExecutor db) async {
    await _createCategoriesTable(db);
    await _createTransactionsTable(db);
    await _createSettingsTable(db);
    await _createRecipientCategoriesTable(db);
    await _createTransactionReceiptChunksTable(db);
    await _createSmsSyncLogTable(db);
    await _createMonthlyPlansTable(db);
    await _seedDefaultCategories(db);
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Stores the category catalogue used to classify money transactions.
  /// Connected to: transactions and recipient_categories through category_id.
  /// Last schema update: version 8, 2026-09-28.
  static Future<void> _createCategoriesTable(DatabaseExecutor db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        kinds TEXT NOT NULL
      )''');

  /// Stores imported and manually-entered income, expense, and transfer rows.
  /// Connected to: categories, debts, and transaction_receipt_chunks.
  /// Last schema update: version 7, 2026-09-27.
  static Future<void> _createTransactionsTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      amount_paise INTEGER NOT NULL CHECK(amount_paise > 0 AND amount_paise <= 999999999999),
      currency TEXT NOT NULL DEFAULT 'INR' CHECK(currency = 'INR'),
      kind TEXT NOT NULL CHECK(kind IN ('expense', 'income', 'transfer')),
      category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
      date TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      source TEXT NOT NULL DEFAULT 'MANUAL',
      bank_name TEXT,
      external_id TEXT,
      recipient_key TEXT,
      has_receipt INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS transactions_date_id ON transactions(date DESC, id DESC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS transactions_external_id ON transactions(external_id) WHERE external_id IS NOT NULL',
    );
  }

  /// Stores small application preferences and synchronization flags.
  /// Connected to: no table; keys are interpreted by repository methods.
  /// Last schema update: version 1, 2026-09-12.
  static Future<void> _createSettingsTable(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  );

  /// Remembers a category choice for a normalized imported recipient name.
  /// Connected to: categories through category_id and transactions logically
  /// through recipient_key.
  /// Last schema update: version 4, 2026-09-27.
  static Future<void> _createRecipientCategoriesTable(DatabaseExecutor db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS recipient_categories (
        recipient_key TEXT PRIMARY KEY,
        category_id INTEGER NOT NULL REFERENCES categories(id)
      )''');

  /// Stores transaction receipt images in bounded chunks.
  /// Connected to: transactions through transaction_id with cascade delete.
  /// Last schema update: version 5, 2026-09-27.
  static Future<void> _createTransactionReceiptChunksTable(
    DatabaseExecutor db,
  ) => db.execute('''CREATE TABLE IF NOT EXISTS transaction_receipt_chunks (
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    bytes BLOB NOT NULL,
    PRIMARY KEY(transaction_id, chunk_index)
  )''');

  /// Records completed SMS synchronization runs for scheduling and diagnostics.
  /// Connected to: no table; imported counts summarize transaction inserts.
  /// Last schema update: version 6, 2026-09-27.
  static Future<void> _createSmsSyncLogTable(DatabaseExecutor db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS sms_sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        completed_at TEXT NOT NULL,
        imported INTEGER NOT NULL,
        automatic INTEGER NOT NULL CHECK(automatic IN (0,1))
      )''');

  /// Stores one planned amount per month, allocation, and subtype.
  /// Connected to: no table yet; future tracking will reconcile these rows with
  /// transactions without coupling the planning schema to transaction history.
  /// Last schema update: version 10, 2026-09-29.
  static Future<void> _createMonthlyPlansTable(DatabaseExecutor db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS monthly_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_year TEXT NOT NULL,
        allocation TEXT NOT NULL CHECK(length(trim(allocation)) > 0),
        subtype TEXT NOT NULL CHECK(length(trim(subtype)) > 0),
        planned_paise INTEGER NOT NULL CHECK(planned_paise >= 0),
        UNIQUE(month_year, allocation, subtype)
      )''');

  static Future<void> _migrateMonthlyPlansV10(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(monthly_plans)');
    if (columns.any((column) => column['name'] == 'allocation')) return;
    await db.execute('ALTER TABLE monthly_plans RENAME TO monthly_plans_v9');
    await _createMonthlyPlansTable(db);
    const allocations = <String, String>{
      'Salary': 'salary_paise',
      'Investment': 'investment_paise',
      'Savings': 'savings_paise',
      'Loan': 'loans_paise',
      'Daily Spend': 'daily_spend_paise',
    };
    for (final entry in allocations.entries) {
      await db.execute(
        '''INSERT INTO monthly_plans
        (month_year, allocation, subtype, planned_paise)
        SELECT substr(month, 1, 7), ?, 'General', ${entry.value}
        FROM monthly_plans_v9''',
        [entry.key],
      );
    }
    await db.execute('DROP TABLE monthly_plans_v9');
  }

  static Future<void> _seedDefaultCategories(DatabaseExecutor db) async {
    final batch = db.batch();
    for (final category in defaultCategories) {
      batch.insert('categories', {
        'id': category.id,
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'kinds': category.kinds.map((kind) => kind.name).join(','),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<MoneyPlan>> plansForMonth(DateTime month) =>
      planning.plansWithTypesForMonth(monthYearKey(month));

  @override
  Future<List<PlanType>> planTypes() => planning.planTypeSuggestions();

  @override
  Future<void> savePlan(MoneyPlan plan) => planning.savePlan(plan);

  @override
  Future<List<MoneyCategory>> categories() async =>
      (await _db.query('categories', orderBy: 'id ASC'))
          .map(
            (row) => MoneyCategory(
              row['id'] as int,
              row['name'] as String,
              row['icon'] as String,
              row['color'] as int,
              (row['kinds'] as String)
                  .split(',')
                  .map(TransactionKind.values.byName)
                  .toSet(),
            ),
          )
          .toList();

  @override
  Future<List<MoneyTransaction>> transactions(DateTime month) async =>
      (await _db.query(
        'transactions',
        where: 'date >= ? AND date < ?',
        whereArgs: [
          dateKey(DateTime(month.year, month.month)),
          dateKey(DateTime(month.year, month.month + 1)),
        ],
        orderBy: 'date DESC, id DESC',
      )).map(MoneyTransaction.fromRow).toList();

  @override
  Future<void> save(MoneyTransaction transaction) async {
    await _db.transaction((db) async {
      await writeTransaction(db, transaction);
      if (transaction.recipientKey != null) {
        await db.insert('recipient_categories', {
          'recipient_key': transaction.recipientKey,
          'category_id': transaction.categoryId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> bulkCategorize(
    List<MoneyTransaction> transactions,
    int categoryId,
  ) async {
    if (transactions.isEmpty) return;
    await _db.transaction((db) async {
      final categoryRows = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (categoryRows.isEmpty) throw ArgumentError('Unknown category');
      final supportedKinds = (categoryRows.single['kinds'] as String).split(
        ',',
      );
      if (transactions.any(
        (transaction) =>
            transaction.id == null ||
            !supportedKinds.contains(transaction.kind.name),
      )) {
        throw ArgumentError('Category does not match transaction type');
      }
      for (final transaction in transactions) {
        final count = await db.update(
          'transactions',
          {'category_id': categoryId},
          where: 'id = ?',
          whereArgs: [transaction.id],
        );
        if (count == 0) throw StateError('Transaction no longer exists');
        if (transaction.recipientKey != null) {
          await db.insert('recipient_categories', {
            'recipient_key': transaction.recipientKey,
            'category_id': categoryId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  @override
  Future<int> importTransactions(List<MoneyTransaction> transactions) async {
    var imported = 0;
    await _db.transaction((db) async {
      for (final transaction in transactions) {
        final existing = transaction.externalId == null
            ? const <Map<String, Object?>>[]
            : await db.query(
                'transactions',
                columns: ['id'],
                where: 'external_id = ?',
                whereArgs: [transaction.externalId],
                limit: 1,
              );
        if (existing.isNotEmpty) continue;
        await writeTransaction(db, transaction);
        imported++;
      }
    });
    return imported;
  }

  @override
  Future<int?> categoryForRecipient(String recipientKey) async {
    final rows = await _db.query(
      'recipient_categories',
      where: 'recipient_key = ?',
      whereArgs: [recipientKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['category_id'] as int;
  }

  @override
  Future<void> saveRecipientCategory(
    String recipientKey,
    int categoryId,
  ) async {
    await _db.insert('recipient_categories', {
      'recipient_key': recipientKey,
      'category_id': categoryId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveTransactionReceipt(
    int transactionId,
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 10 MB.');
    }
    await _db.transaction((db) async {
      await db.delete(
        'transaction_receipt_chunks',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      for (
        var offset = 0, index = 0;
        offset < bytes.length;
        offset += 262144, index++
      ) {
        final end = (offset + 262144).clamp(0, bytes.length);
        await db.insert('transaction_receipt_chunks', {
          'transaction_id': transactionId,
          'chunk_index': index,
          'bytes': bytes.sublist(offset, end),
        });
      }
      await db.update(
        'transactions',
        {'has_receipt': 1},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  @override
  Future<Uint8List?> transactionReceipt(int transactionId) async {
    final rows = await _db.query(
      'transaction_receipt_chunks',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'chunk_index ASC',
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(
      rows.expand((row) => row['bytes'] as Uint8List).toList(),
    );
  }

  @override
  Future<void> deleteTransactionReceipt(int transactionId) async {
    await _db.transaction((db) async {
      await db.delete(
        'transaction_receipt_chunks',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      await db.update(
        'transactions',
        {'has_receipt': 0},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  @override
  Future<bool> wasSyncedOn(DateTime date) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['sms_sync_${dateKey(date)}'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  @override
  Future<void> markSynced(DateTime date) async {
    await _db.insert('settings', {
      'key': 'sms_sync_${dateKey(date)}',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<DateTime?> lastSmsSyncAt() async {
    final rows = await _db.query(
      'sms_sync_log',
      orderBy: 'completed_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DateTime.parse(rows.single['completed_at'] as String);
  }

  @override
  Future<void> recordSmsSync({
    required DateTime completedAt,
    required int imported,
    required bool automatic,
  }) async {
    await _db.insert('sms_sync_log', {
      'completed_at': completedAt.toIso8601String(),
      'imported': imported,
      'automatic': automatic ? 1 : 0,
    });
  }

  @override
  Future<int> writeTransaction(
    DatabaseExecutor db,
    MoneyTransaction transaction,
  ) async {
    if (transaction.title.trim().isEmpty ||
        transaction.amountPaise <= 0 ||
        transaction.amountPaise > 999999999999 ||
        transaction.date.year < 1900 ||
        transaction.date.year > 2100) {
      throw ArgumentError('Invalid transaction');
    }
    final categories = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [transaction.categoryId],
    );
    final eligible =
        categories.isNotEmpty &&
        (categories.single['kinds'] as String)
            .split(',')
            .contains(transaction.kind.name);
    if (!eligible) {
      throw ArgumentError('Category does not match transaction type');
    }
    final row = transaction.toRow()
      ..['transaction_type'] = transaction.kind.name;
    if (transaction.id == null) {
      return db.insert('transactions', row);
    } else {
      final shares = await db.rawQuery(
        'SELECT COUNT(*) AS count, COALESCE(SUM(amount_paise),0) AS total FROM debts WHERE transaction_id = ?',
        [transaction.id],
      );
      if ((shares.single['count'] as int) > 0 &&
          (transaction.kind != TransactionKind.expense ||
              transaction.amountPaise < (shares.single['total'] as int))) {
        throw const DebtValidationException(
          'This payment has debt shares. Keep it as an expense and do not reduce it below their total.',
        );
      }
      final count = await db.update(
        'transactions',
        row,
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      if (count == 0) throw StateError('Transaction no longer exists');
      return transaction.id!;
    }
  }

  @override
  Future<void> delete(int id) async {
    await _db.transaction((db) async {
      final linked = await db.query(
        'debts',
        columns: ['id'],
        where: 'transaction_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (linked.isNotEmpty) {
        throw const DebtValidationException(
          'This payment has debt records. Remove those records first if you want to delete the payment.',
        );
      }
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<String> loadTheme() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['theme'],
    );
    return rows.isEmpty ? 'system' : rows.first['value'] as String;
  }

  @override
  Future<void> saveTheme(String theme) async {
    await _db.insert('settings', {
      'key': 'theme',
      'value': theme,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> loadSmsConsent() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['sms_consent'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  @override
  Future<void> saveSmsConsent(bool granted) async {
    await _db.insert('settings', {
      'key': 'sms_consent',
      'value': granted ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> loadInitialSmsSyncComplete() async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['sms_initial_sync_complete'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  @override
  Future<void> saveInitialSmsSyncComplete() async {
    await _db.insert('settings', {
      'key': 'sms_initial_sync_complete',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
