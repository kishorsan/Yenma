import 'package:sqflite/sqflite.dart';

import 'commitments_data.dart';
import 'planning_data.dart';
import 'reference_data.dart';
import 'splitting_data.dart';

/// Creates the DBML-backed schema that is additive to the legacy money/debt
/// tables. Existing columns remain in place because the current UI still uses
/// them; canonical foreign keys are populated alongside those columns.
Future<void> createStructuredDataSchema(DatabaseExecutor db) async {
  await createReferenceDataSchema(db);
  await createPlanningSchema(db);
  await createSplittingSchema(db);
  await createCommitmentsSchema(db);
  await _extendLegacyMoneyTables(db);
  await _backfillCanonicalReferences(db);
  await _createCompatibilityForeignKeyTriggers(db);
}

Future<void> _createCompatibilityForeignKeyTriggers(DatabaseExecutor db) async {
  await db.execute('''CREATE TRIGGER IF NOT EXISTS transactions_bank_insert
    BEFORE INSERT ON transactions WHEN NEW.bank_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM banks WHERE id = NEW.bank_id)
    BEGIN SELECT RAISE(ABORT, 'invalid transactions.bank_id'); END''');
  await db.execute('''CREATE TRIGGER IF NOT EXISTS transactions_bank_update
    BEFORE UPDATE OF bank_id ON transactions WHEN NEW.bank_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM banks WHERE id = NEW.bank_id)
    BEGIN SELECT RAISE(ABORT, 'invalid transactions.bank_id'); END''');
  await db.execute('''CREATE TRIGGER IF NOT EXISTS transactions_associate_insert
    BEFORE INSERT ON transactions WHEN NEW.associate_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM associates WHERE id = NEW.associate_id)
    BEGIN SELECT RAISE(ABORT, 'invalid transactions.associate_id'); END''');
  await db.execute('''CREATE TRIGGER IF NOT EXISTS transactions_associate_update
    BEFORE UPDATE OF associate_id ON transactions WHEN NEW.associate_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM associates WHERE id = NEW.associate_id)
    BEGIN SELECT RAISE(ABORT, 'invalid transactions.associate_id'); END''');
  await db.execute('''CREATE TRIGGER IF NOT EXISTS debts_associate_insert
    BEFORE INSERT ON debts WHEN NEW.associate_id IS NULL
      OR NOT EXISTS (SELECT 1 FROM associates WHERE id = NEW.associate_id)
    BEGIN SELECT RAISE(ABORT, 'invalid debts.associate_id'); END''');
  await db.execute('''CREATE TRIGGER IF NOT EXISTS debts_associate_update
    BEFORE UPDATE OF associate_id ON debts WHEN NEW.associate_id IS NULL
      OR NOT EXISTS (SELECT 1 FROM associates WHERE id = NEW.associate_id)
    BEGIN SELECT RAISE(ABORT, 'invalid debts.associate_id'); END''');
}

Future<void> _extendLegacyMoneyTables(DatabaseExecutor db) async {
  await _addColumn(
    db,
    'transactions',
    'transaction_type',
    "TEXT NOT NULL DEFAULT 'expense'",
  );
  await _addColumn(db, 'transactions', 'bank_id', 'INTEGER');
  await _addColumn(db, 'transactions', 'associate_id', 'INTEGER');
  await _addColumn(db, 'debts', 'associate_id', 'INTEGER');
  await _addColumn(
    db,
    'debts',
    'debt_type',
    "TEXT NOT NULL DEFAULT 'PERSONAL'",
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS transactions_bank ON transactions(bank_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS transactions_associate ON transactions(associate_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS debts_associate ON debts(associate_id)',
  );
  await db.execute(
    "UPDATE transactions SET transaction_type = kind "
    "WHERE transaction_type != kind",
  );
}

Future<void> _addColumn(
  DatabaseExecutor db,
  String table,
  String column,
  String definition,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  if (columns.any((row) => row['name'] == column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}

Future<void> _backfillCanonicalReferences(DatabaseExecutor db) async {
  final legacyBanks = await db.query(
    'transactions',
    columns: ['bank_name'],
    where: 'bank_name IS NOT NULL',
    distinct: true,
  );
  for (final row in legacyBanks) {
    final name = (row['bank_name'] as String).trim();
    if (name.isEmpty) continue;
    final code =
        'LEGACY_${name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_')}';
    await db.insert('banks', {
      'bank_name': name,
      'bank_code': code,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  final people = await db.query('debt_people', orderBy: 'name_key ASC');
  for (final person in people) {
    await db.insert('associates', {
      'name': person['name'],
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await db.execute('''UPDATE debts
    SET associate_id = (
      SELECT a.id FROM associates a
      WHERE lower(trim(a.name)) = lower(trim(debts.person)) LIMIT 1
    )
    WHERE associate_id IS NULL''');
  await db.execute('''UPDATE transactions
    SET bank_id = (
      SELECT b.id FROM banks b WHERE b.bank_name = transactions.bank_name LIMIT 1
    )
    WHERE bank_id IS NULL AND bank_name IS NOT NULL''');
  final legacyPlanTable = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'monthly_plans'",
  );
  if (legacyPlanTable.isNotEmpty) {
    await db.execute('''INSERT OR IGNORE INTO plan_type(plan)
      SELECT DISTINCT allocation FROM monthly_plans''');
    await db.execute('''INSERT OR IGNORE INTO money_plans
      (plan_id, note, planned_amount, remaining_amount, month_year)
      SELECT pt.id, mp.subtype, mp.planned_paise, mp.planned_paise, mp.month_year
      FROM monthly_plans mp JOIN plan_type pt ON pt.plan = mp.allocation''');
  }
}
