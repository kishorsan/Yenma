import 'package:sqflite/sqflite.dart';

import '../../domain/money.dart';

/// Creates the core transaction tables and their initial reference data.
Future<void> createMoneySchema(DatabaseExecutor db) async {
  await createCategoriesTable(db);
  await createTransactionsTable(db);
  await createSettingsTable(db);
  await createRecipientCategoriesTable(db);
  await createTransactionReceiptChunksTable(db);
  await createSmsSyncLogTable(db);
  await createMonthlyPlansTable(db);
  await createImportFoundationSchema(db);
  await createStatementImportProfilesTable(db);
  await seedDefaultCategories(db);
}

Future<void> createStatementImportProfilesTable(DatabaseExecutor db) =>
    db.execute('''CREATE TABLE IF NOT EXISTS statement_import_profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      source_key TEXT NOT NULL UNIQUE,
      file_format TEXT NOT NULL CHECK(file_format IN ('csv','xlsx')),
      sheet_name TEXT,
      header_row INTEGER NOT NULL CHECK(header_row >= 0),
      columns_json TEXT NOT NULL,
      defaults_json TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');

/// Creates the durable staging, provenance, cursor, and reconciliation layer
/// used by all transaction import sources.
Future<void> createImportFoundationSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS financial_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    institution TEXT NOT NULL,
    instrument_type TEXT NOT NULL CHECK(instrument_type IN ('bankAccount','creditCard')),
    instrument_last4 TEXT,
    display_name TEXT NOT NULL,
    UNIQUE(institution, instrument_type, instrument_last4)
  )''');
  await db.execute(
    "CREATE UNIQUE INDEX IF NOT EXISTS financial_accounts_identity ON financial_accounts(institution, instrument_type, IFNULL(instrument_last4, ''))",
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS import_inbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    source_item_id TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    raw_payload TEXT NOT NULL,
    received_at TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('imported','duplicate','rejected')),
    reason TEXT,
    transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    account_id INTEGER REFERENCES financial_accounts(id) ON DELETE SET NULL,
    UNIQUE(source, source_item_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS import_inbox_payload_hash ON import_inbox(source, payload_hash)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS transaction_provenance (
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    inbox_id INTEGER NOT NULL UNIQUE REFERENCES import_inbox(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    source_item_id TEXT NOT NULL,
    PRIMARY KEY(transaction_id, inbox_id)
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS import_cursors (
    source TEXT PRIMARY KEY,
    covered_through TEXT NOT NULL
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS import_reconciliations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_debit_transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    card_payment_transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'suggested' CHECK(status IN ('suggested','confirmed','dismissed')),
    amount_paise INTEGER NOT NULL,
    date_distance_days INTEGER NOT NULL,
    UNIQUE(account_debit_transaction_id, card_payment_transaction_id)
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS import_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    started_at TEXT NOT NULL,
    completed_at TEXT NOT NULL,
    from_at TEXT NOT NULL,
    until_at TEXT NOT NULL,
    automatic INTEGER NOT NULL CHECK(automatic IN (0,1)),
    scanned INTEGER NOT NULL,
    parsed INTEGER NOT NULL,
    imported INTEGER NOT NULL,
    duplicates INTEGER NOT NULL,
    rejected INTEGER NOT NULL,
    reconciliation_suggestions INTEGER NOT NULL,
    error_code TEXT
  )''');
}

/// Adds a column safely when upgrading databases created by older versions.
Future<void> addColumnIfMissing(
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
Future<void> createCategoriesTable(DatabaseExecutor db) =>
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
Future<void> createTransactionsTable(DatabaseExecutor db) async {
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
      instrument_type TEXT CHECK(instrument_type IN ('bankAccount','creditCard')),
      instrument_last4 TEXT,
      import_role TEXT CHECK(import_role IN ('cardPurchase','accountDebit','accountCredit','cardPayment')),
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
Future<void> createSettingsTable(DatabaseExecutor db) => db.execute(
  'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
);

/// Remembers a category choice for a normalized imported recipient name.
/// Connected to: categories through category_id and transactions logically
/// through recipient_key.
/// Last schema update: version 4, 2026-09-27.
Future<void> createRecipientCategoriesTable(DatabaseExecutor db) =>
    db.execute('''CREATE TABLE IF NOT EXISTS recipient_categories (
      recipient_key TEXT PRIMARY KEY,
      category_id INTEGER NOT NULL REFERENCES categories(id)
    )''');

/// Stores transaction receipt images in bounded chunks.
/// Connected to: transactions through transaction_id with cascade delete.
/// Last schema update: version 5, 2026-09-27.
Future<void> createTransactionReceiptChunksTable(DatabaseExecutor db) =>
    db.execute('''CREATE TABLE IF NOT EXISTS transaction_receipt_chunks (
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    bytes BLOB NOT NULL,
    PRIMARY KEY(transaction_id, chunk_index)
  )''');

/// Records completed SMS synchronization runs for scheduling and diagnostics.
/// Connected to: no table; imported counts summarize transaction inserts.
/// Last schema update: version 6, 2026-09-27.
Future<void> createSmsSyncLogTable(DatabaseExecutor db) =>
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
Future<void> createMonthlyPlansTable(DatabaseExecutor db) =>
    db.execute('''CREATE TABLE IF NOT EXISTS monthly_plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      month_year TEXT NOT NULL,
      allocation TEXT NOT NULL CHECK(length(trim(allocation)) > 0),
      subtype TEXT NOT NULL CHECK(length(trim(subtype)) > 0),
      planned_paise INTEGER NOT NULL CHECK(planned_paise >= 0),
      UNIQUE(month_year, allocation, subtype)
    )''');

/// Converts the pre-v10 wide monthly-plan table into allocation rows.
Future<void> migrateMonthlyPlansV10(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(monthly_plans)');
  if (columns.any((column) => column['name'] == 'allocation')) return;
  await db.execute('ALTER TABLE monthly_plans RENAME TO monthly_plans_v9');
  await createMonthlyPlansTable(db);
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

/// Inserts built-in categories without replacing user-visible stored values.
Future<void> seedDefaultCategories(DatabaseExecutor db) async {
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
