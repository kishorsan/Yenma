import 'package:sqflite/sqflite.dart';

/// Creates the lookup tables shared by transactions, plans, debts and splits.
Future<void> createReferenceDataSchema(DatabaseExecutor db) async {
  // `banks` is the canonical catalogue behind a transaction's optional bank.
  await db.execute('''CREATE TABLE IF NOT EXISTS banks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bank_name TEXT NOT NULL,
    bank_code TEXT NOT NULL UNIQUE,
    is_tracked INTEGER NOT NULL DEFAULT 1 CHECK(is_tracked IN (0,1)),
    is_credit_card INTEGER NOT NULL DEFAULT 0 CHECK(is_credit_card IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''');

  // `associates` gives debts and split participants a stable person identity.
  await db.execute('''CREATE TABLE IF NOT EXISTS associates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL CHECK(length(trim(name)) > 0),
    phone_number TEXT UNIQUE
  )''');
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS associates_normalized_name '
    'ON associates(lower(trim(name)))',
  );

  // `plan_type` stores reusable names selected while creating monthly plans.
  await db.execute('''CREATE TABLE IF NOT EXISTS plan_type (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan TEXT NOT NULL UNIQUE
  )''');
}
