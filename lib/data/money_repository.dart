import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'dart:typed_data';

import '../domain/money.dart';
import '../domain/debt.dart';
import 'debt_repository.dart';

abstract interface class MoneyRepository implements DebtRepository {
  Future<void> initialize();
  Future<List<MoneyCategory>> categories();
  Future<List<MoneyTransaction>> transactions(DateTime month);
  Future<void> save(MoneyTransaction transaction);
  Future<int> importTransactions(List<MoneyTransaction> transactions);
  Future<int?> categoryForRecipient(String recipientKey);
  Future<void> saveRecipientCategory(String recipientKey, int categoryId);
  Future<void> saveTransactionReceipt(int transactionId, Uint8List bytes);
  Future<Uint8List?> transactionReceipt(int transactionId);
  Future<void> deleteTransactionReceipt(int transactionId);
  Future<bool> wasSyncedOn(DateTime date);
  Future<void> markSynced(DateTime date);
  Future<DateTime?> lastSmsSyncAt();
  Future<void> recordSmsSync({required DateTime completedAt, required int imported, required bool automatic});
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
    with SqliteDebtOperations
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
  Future<void> initialize() async {
    if (_database != null) return;
    final path = _path ?? p.join(await _factory.getDatabasesPath(), 'yenma.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE categories (
          id INTEGER PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL,
          color INTEGER NOT NULL, kinds TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL CHECK(length(trim(title)) > 0),
          amount_paise INTEGER NOT NULL CHECK(amount_paise > 0 AND amount_paise <= 999999999999),
          currency TEXT NOT NULL DEFAULT 'INR' CHECK(currency = 'INR'),
          kind TEXT NOT NULL CHECK(kind IN ('expense', 'income', 'transfer')),
          category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
          date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL DEFAULT 'MANUAL', bank_name TEXT,
          external_id TEXT, recipient_key TEXT, has_receipt INTEGER NOT NULL DEFAULT 0)''');
          await db.execute(
            'CREATE INDEX transactions_date_id ON transactions(date DESC, id DESC)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute('CREATE UNIQUE INDEX transactions_external_id ON transactions(external_id) WHERE external_id IS NOT NULL');
          await db.execute('CREATE TABLE recipient_categories (recipient_key TEXT PRIMARY KEY, category_id INTEGER NOT NULL REFERENCES categories(id))');
          await db.execute('CREATE TABLE transaction_receipt_chunks (transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE, chunk_index INTEGER NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(transaction_id, chunk_index))');
          await db.execute('CREATE TABLE sms_sync_log (id INTEGER PRIMARY KEY AUTOINCREMENT, completed_at TEXT NOT NULL, imported INTEGER NOT NULL, automatic INTEGER NOT NULL CHECK(automatic IN (0,1)))');
          final batch = db.batch();
          for (final category in defaultCategories) {
            batch.insert('categories', {
              'id': category.id,
              'name': category.name,
              'icon': category.icon,
              'color': category.color,
              'kinds': category.kinds.map((kind) => kind.name).join(','),
            });
          }
          await batch.commit(noResult: true);
          await createDebtSchema(db);
          await createPeopleSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await createDebtSchema(db);
          if (oldVersion < 3) await createPeopleSchema(db);
          if (oldVersion < 4) {
            await db.execute("ALTER TABLE transactions ADD COLUMN bank_name TEXT");
            await db.execute("ALTER TABLE transactions ADD COLUMN external_id TEXT");
            await db.execute("ALTER TABLE transactions ADD COLUMN recipient_key TEXT");
            await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS transactions_external_id ON transactions(external_id) WHERE external_id IS NOT NULL");
            await db.execute("CREATE TABLE IF NOT EXISTS recipient_categories (recipient_key TEXT PRIMARY KEY, category_id INTEGER NOT NULL REFERENCES categories(id))");
          }
          if (oldVersion < 5) {
            await db.execute('ALTER TABLE transactions ADD COLUMN has_receipt INTEGER NOT NULL DEFAULT 0');
            await db.execute('CREATE TABLE transaction_receipt_chunks (transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE, chunk_index INTEGER NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(transaction_id, chunk_index))');
            // Move legacy linked debt bills to their parent transaction without
            // dropping the old chunks, so existing debt history remains readable.
            await db.execute('''INSERT OR IGNORE INTO transaction_receipt_chunks
              (transaction_id, chunk_index, bytes)
              SELECT d.transaction_id, c.chunk_index, c.bytes
              FROM debts d JOIN debt_receipt_chunks c ON c.debt_id = d.id
              WHERE d.transaction_id IS NOT NULL''');
            await db.execute('''UPDATE transactions SET has_receipt = 1
              WHERE id IN (SELECT DISTINCT transaction_id FROM debts
                           WHERE transaction_id IS NOT NULL AND has_receipt = 1)''');
          }
          if (oldVersion < 6) {
            await db.execute('CREATE TABLE sms_sync_log (id INTEGER PRIMARY KEY AUTOINCREMENT, completed_at TEXT NOT NULL, imported INTEGER NOT NULL, automatic INTEGER NOT NULL CHECK(automatic IN (0,1)))');
          }
        },
      ),
    );
  }

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
  Future<int> importTransactions(List<MoneyTransaction> transactions) async {
    var imported = 0;
    await _db.transaction((db) async {
      for (final transaction in transactions) {
        final existing = transaction.externalId == null
            ? const <Map<String, Object?>>[]
            : await db.query('transactions', columns: ['id'], where: 'external_id = ?', whereArgs: [transaction.externalId], limit: 1);
        if (existing.isNotEmpty) continue;
        await writeTransaction(db, transaction);
        imported++;
      }
    });
    return imported;
  }

  @override
  Future<int?> categoryForRecipient(String recipientKey) async {
    final rows = await _db.query('recipient_categories', where: 'recipient_key = ?', whereArgs: [recipientKey], limit: 1);
    return rows.isEmpty ? null : rows.single['category_id'] as int;
  }

  @override
  Future<void> saveRecipientCategory(String recipientKey, int categoryId) async {
    await _db.insert('recipient_categories', {'recipient_key': recipientKey, 'category_id': categoryId}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveTransactionReceipt(int transactionId, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) throw ArgumentError('Choose an image smaller than 10 MB.');
    await _db.transaction((db) async {
      await db.delete('transaction_receipt_chunks', where: 'transaction_id = ?', whereArgs: [transactionId]);
      for (var offset = 0, index = 0; offset < bytes.length; offset += 262144, index++) {
        final end = (offset + 262144).clamp(0, bytes.length);
        await db.insert('transaction_receipt_chunks', {'transaction_id': transactionId, 'chunk_index': index, 'bytes': bytes.sublist(offset, end)});
      }
      await db.update('transactions', {'has_receipt': 1}, where: 'id = ?', whereArgs: [transactionId]);
    });
  }

  @override
  Future<Uint8List?> transactionReceipt(int transactionId) async {
    final rows = await _db.query('transaction_receipt_chunks', where: 'transaction_id = ?', whereArgs: [transactionId], orderBy: 'chunk_index ASC');
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.expand((row) => row['bytes'] as Uint8List).toList());
  }

  @override
  Future<void> deleteTransactionReceipt(int transactionId) async {
    await _db.transaction((db) async {
      await db.delete('transaction_receipt_chunks', where: 'transaction_id = ?', whereArgs: [transactionId]);
      await db.update('transactions', {'has_receipt': 0}, where: 'id = ?', whereArgs: [transactionId]);
    });
  }

  @override
  Future<bool> wasSyncedOn(DateTime date) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: ['sms_sync_${dateKey(date)}'], limit: 1);
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  @override
  Future<void> markSynced(DateTime date) async {
    await _db.insert('settings', {'key': 'sms_sync_${dateKey(date)}', 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<DateTime?> lastSmsSyncAt() async {
    final rows = await _db.query('sms_sync_log', orderBy: 'completed_at DESC, id DESC', limit: 1);
    return rows.isEmpty ? null : DateTime.parse(rows.single['completed_at'] as String);
  }

  @override
  Future<void> recordSmsSync({required DateTime completedAt, required int imported, required bool automatic}) async {
    await _db.insert('sms_sync_log', {'completed_at': completedAt.toIso8601String(), 'imported': imported, 'automatic': automatic ? 1 : 0});
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
    if (transaction.id == null) {
      return db.insert('transactions', transaction.toRow());
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
        transaction.toRow(),
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
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: ['sms_consent'], limit: 1);
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  @override
  Future<void> saveSmsConsent(bool granted) async {
    await _db.insert('settings', {'key': 'sms_consent', 'value': granted ? '1' : '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> loadInitialSmsSyncComplete() async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: ['sms_initial_sync_complete'], limit: 1);
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  @override
  Future<void> saveInitialSmsSyncComplete() async {
    await _db.insert('settings', {'key': 'sms_initial_sync_complete', 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
