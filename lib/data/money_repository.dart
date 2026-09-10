import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/money.dart';
import '../domain/debt.dart';
import 'debt_repository.dart';

abstract interface class MoneyRepository implements DebtRepository {
  Future<void> initialize();
  Future<List<MoneyCategory>> categories();
  Future<List<MoneyTransaction>> transactions(DateTime month);
  Future<void> save(MoneyTransaction transaction);
  Future<void> delete(int id);
  Future<String> loadTheme();
  Future<void> saveTheme(String theme);
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
        version: 2,
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
          source TEXT NOT NULL DEFAULT 'MANUAL')''');
          await db.execute(
            'CREATE INDEX transactions_date_id ON transactions(date DESC, id DESC)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
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
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await createDebtSchema(db);
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
    await _db.transaction((db) => writeTransaction(db, transaction));
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
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
