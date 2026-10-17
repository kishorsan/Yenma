import 'package:sqflite/sqflite.dart';

/// Creates tables used for split groups, allocations and debt-linked shares.
Future<void> createSplittingSchema(DatabaseExecutor db) async {
  // `associate_group` stores a named collection of recurring participants.
  await db.execute('''CREATE TABLE IF NOT EXISTS associate_group (
    group_id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_name TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''');
  await _addSplitColumn(
    db,
    'associate_group',
    'note',
    "TEXT NOT NULL DEFAULT ''",
  );

  // This join table records which associates belong to each group.
  await db.execute('''CREATE TABLE IF NOT EXISTS associate_group_mapping (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL REFERENCES associate_group(group_id) ON DELETE CASCADE,
    associate_id INTEGER NOT NULL REFERENCES associates(id) ON DELETE RESTRICT,
    UNIQUE(group_id, associate_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS associate_group_mapping_associate '
    'ON associate_group_mapping(associate_id)',
  );

  // `split_allocation` is the parent expense recorded against a split group.
  await db.execute('''CREATE TABLE IF NOT EXISTS split_allocation (
    allocation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    associate_group_id INTEGER REFERENCES associate_group(group_id) ON DELETE SET NULL,
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
    title TEXT NOT NULL DEFAULT 'Shared expense',
    paid_by_associate_id INTEGER REFERENCES associates(id) ON DELETE RESTRICT,
    note TEXT NOT NULL DEFAULT '',
    date TEXT NOT NULL
  )''');
  await _addSplitColumn(
    db,
    'split_allocation',
    'title',
    "TEXT NOT NULL DEFAULT 'Shared expense'",
  );
  await _addSplitColumn(
    db,
    'split_allocation',
    'paid_by_associate_id',
    'INTEGER',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_allocation_group '
    'ON split_allocation(associate_group_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_allocation_date ON split_allocation(date)',
  );

  // Legacy allocation rows use this table for associate-level share amounts.
  await db.execute('''CREATE TABLE IF NOT EXISTS split_allocation_mapping (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    allocation_id INTEGER NOT NULL REFERENCES split_allocation(allocation_id) ON DELETE CASCADE,
    associate_id INTEGER NOT NULL REFERENCES associates(id) ON DELETE RESTRICT,
    split_amount_paise INTEGER NOT NULL CHECK(split_amount_paise > 0),
    UNIQUE(allocation_id, associate_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_allocation_mapping_associate '
    'ON split_allocation_mapping(associate_id)',
  );

  // Current split entries retain display names and optional generated debts.
  await db.execute('''CREATE TABLE IF NOT EXISTS split_allocation_share (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    allocation_id INTEGER NOT NULL REFERENCES split_allocation(allocation_id) ON DELETE CASCADE,
    associate_id INTEGER REFERENCES associates(id) ON DELETE RESTRICT,
    participant_name TEXT NOT NULL,
    is_me INTEGER NOT NULL DEFAULT 0 CHECK(is_me IN (0,1)),
    split_amount_paise INTEGER NOT NULL CHECK(split_amount_paise > 0),
    debt_id INTEGER REFERENCES debts(id) ON DELETE SET NULL,
    CHECK((is_me = 1 AND associate_id IS NULL) OR (is_me = 0 AND associate_id IS NOT NULL)),
    UNIQUE(allocation_id, associate_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_share_allocation '
    'ON split_allocation_share(allocation_id)',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS split_share_one_me '
    'ON split_allocation_share(allocation_id) WHERE is_me = 1',
  );
}

/// Adds a column only when upgrading a database that does not contain it yet.
Future<void> _addSplitColumn(
  DatabaseExecutor db,
  String table,
  String column,
  String definition,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  if (columns.any((row) => row['name'] == column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}
