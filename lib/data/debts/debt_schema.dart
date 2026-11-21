import 'package:sqflite/sqflite.dart';

import '../../domain/debt.dart';

/// Creates debt, repayment and receipt tables used by personal debts.
Future<void> createDebtSchema(DatabaseExecutor db) async {
  await _createDebtsTable(db);
  await _createDebtReceiptChunksTable(db);
  await _createRepaymentsTable(db);
}

/// Stores an amount owed to or by the user, optionally linked to a payment.
/// Connected to: transactions through transaction_id; parent of repayments and
/// debt_receipt_chunks.
/// Last schema update: version 5, 2026-09-27.
Future<void> _createDebtsTable(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS debts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id INTEGER REFERENCES transactions(id) ON DELETE RESTRICT,
    person TEXT NOT NULL CHECK(length(trim(person)) > 0),
    title TEXT NOT NULL CHECK(length(trim(title)) > 0),
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0 AND amount_paise <= 999999999999),
    direction TEXT NOT NULL CHECK(direction IN ('owedToMe','iOwe')),
    date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
    has_receipt INTEGER NOT NULL DEFAULT 0 CHECK(has_receipt IN (0,1)))''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS debts_transaction ON debts(transaction_id)',
  );
}

/// Stores debt receipt images in chunks small enough for Android CursorWindow.
/// Connected to: debts through debt_id with cascade delete.
/// Last schema update: version 2, 2026-09-12.
Future<void> _createDebtReceiptChunksTable(DatabaseExecutor db) =>
    db.execute('''CREATE TABLE IF NOT EXISTS debt_receipt_chunks (
    debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL, bytes BLOB NOT NULL CHECK(length(bytes) <= 262144),
    PRIMARY KEY(debt_id, chunk_index))''');

/// Stores repayments made against a debt record.
/// Connected to: debts through debt_id with cascade delete.
/// Last schema update: version 2, 2026-09-12.
Future<void> _createRepaymentsTable(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS repayments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
    date TEXT NOT NULL, note TEXT NOT NULL DEFAULT '')''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS repayments_debt ON repayments(debt_id)',
  );
}

/// Creates normalized person suggestions and backfills names from existing debts.
Future<void> createPeopleSchema(DatabaseExecutor db) async {
  await _createDebtPeopleTable(db);
  final existing = await db.query(
    'debts',
    columns: ['person'],
    orderBy: 'id ASC',
  );
  final batch = db.batch();
  for (final row in existing) {
    final name = normalizePersonName(row['person'] as String);
    if (name.isNotEmpty) {
      batch.insert('debt_people', {
        'name_key': personNameKey(name),
        'name': name,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
  await batch.commit(noResult: true);
}

/// Stores normalized display names reused by debt forms and suggestions.
/// Connected to: debts logically through normalized debts.person values; no
/// foreign key is used so historical debt text remains immutable.
/// Last schema update: version 3, 2026-09-12.
Future<void> _createDebtPeopleTable(DatabaseExecutor db) =>
    db.execute('''CREATE TABLE IF NOT EXISTS debt_people (
    name_key TEXT PRIMARY KEY,
    name TEXT NOT NULL CHECK(length(trim(name)) > 0)
  )''');
