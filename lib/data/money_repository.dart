import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'dart:convert';

import 'dart:typed_data';

import '../domain/money.dart';
import '../domain/debt.dart';
import '../domain/monthly_plan.dart';
import '../domain/import_foundation.dart';
import '../domain/statement_import.dart';
import 'application_support_data.dart';
import 'commitments_data.dart';
import 'debt_repository.dart';
import 'money/money_repository_contract.dart';
import 'money/money_schema.dart';
import 'planning_data.dart';
import 'reference_data.dart';
import 'splitting_data.dart';
import 'yenma_schema.dart';

export 'money/money_repository_contract.dart';

String _stablePayloadHash(String value) {
  // FNV-1a is used as a deterministic local deduplication key. It is not a
  // security boundary and the original payload remains available for audit.
  var hash = 0xcbf29ce484222325;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

StatementImportProfile _statementProfileFromRow(Map<String, Object?> row) {
  Map<StatementField, String> fields(String value) {
    final decoded = Map<String, dynamic>.from(jsonDecode(value) as Map);
    return {
      for (final entry in decoded.entries)
        StatementField.values.byName(entry.key): entry.value as String,
    };
  }

  return StatementImportProfile(
    id: row['id'] as int,
    name: row['name'] as String,
    sourceKey: row['source_key'] as String,
    format: StatementFileFormat.values.byName(row['file_format'] as String),
    sheetName: row['sheet_name'] as String?,
    headerRow: row['header_row'] as int,
    columns: fields(row['columns_json'] as String),
    defaults: fields(row['defaults_json'] as String),
  );
}

/// Main SQLite repository that composes all feature-specific data operations.
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
  /// Opens the database once and runs creation or incremental migration logic.
  Future<void> initialize() async {
    if (_database != null) return;
    final path = _path ?? p.join(await _factory.getDatabasesPath(), 'yenma.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 19,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await createMoneySchema(db);
          await createDebtSchema(db);
          await createPeopleSchema(db);
          await createStructuredDataSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await createDebtSchema(db);
          if (oldVersion < 3) await createPeopleSchema(db);
          if (oldVersion < 4) {
            await addColumnIfMissing(db, 'transactions', 'bank_name', 'TEXT');
            await addColumnIfMissing(db, 'transactions', 'external_id', 'TEXT');
            await addColumnIfMissing(
              db,
              'transactions',
              'recipient_key',
              'TEXT',
            );
            await createTransactionsTable(db);
            await createRecipientCategoriesTable(db);
          }
          if (oldVersion < 5) {
            await addColumnIfMissing(
              db,
              'transactions',
              'has_receipt',
              'INTEGER NOT NULL DEFAULT 0',
            );
            await createTransactionReceiptChunksTable(db);
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
            await createSmsSyncLogTable(db);
          }
          if (oldVersion < 7) {
            await db.execute(
              "UPDATE transactions SET date = date || 'T12:00:00.000' "
              "WHERE instr(date, 'T') = 0 AND instr(date, ' ') = 0",
            );
          }
          if (oldVersion < 8) {
            await seedDefaultCategories(db);
          }
          if (oldVersion < 9) {
            await createMonthlyPlansTable(db);
          } else if (oldVersion < 10) {
            await migrateMonthlyPlansV10(db);
          }
          if (oldVersion < 11) {
            await createStructuredDataSchema(db);
          }
          if (oldVersion < 12) {
            await addColumnIfMissing(
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
            await addColumnIfMissing(
              db,
              'subscriptions',
              'billing_month',
              'INTEGER NOT NULL DEFAULT 1 CHECK(billing_month BETWEEN 1 AND 12)',
            );
          }
          if (oldVersion < 15) {
            // Some legacy databases only contain the structured tables that
            // were used at the time. Ensure the commitment tables exist before
            // extending them with the EMI-specific columns.
            await createCommitmentsSchema(db);
            await addColumnIfMissing(
              db,
              'loans',
              'emi_name',
              "TEXT NOT NULL DEFAULT 'EMI'",
            );
            await addColumnIfMissing(
              db,
              'loans',
              'processing_fee_paise',
              'INTEGER NOT NULL DEFAULT 0 CHECK(processing_fee_paise >= 0)',
            );
            await addColumnIfMissing(
              db,
              'loans',
              'billing_day',
              'INTEGER NOT NULL DEFAULT 1 CHECK(billing_day BETWEEN 1 AND 28)',
            );
            await addColumnIfMissing(
              db,
              'loans',
              'emi_ownership',
              "TEXT NOT NULL DEFAULT 'MINE' CHECK(emi_ownership IN ('MINE','THROUGH_ME'))",
            );
            await addColumnIfMissing(
              db,
              'loan_tracking',
              'gst_paise',
              'INTEGER NOT NULL DEFAULT 0 CHECK(gst_paise >= 0)',
            );
          }
          if (oldVersion < 16) {
            final transactionTable = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'transactions'",
            );
            if (transactionTable.isNotEmpty) {
              await addColumnIfMissing(
                db,
                'transactions',
                'instrument_type',
                "TEXT CHECK(instrument_type IN ('bankAccount','creditCard'))",
              );
              await addColumnIfMissing(
                db,
                'transactions',
                'instrument_last4',
                'TEXT',
              );
              await addColumnIfMissing(
                db,
                'transactions',
                'import_role',
                "TEXT CHECK(import_role IN ('cardPurchase','accountDebit','accountCredit','cardPayment'))",
              );
            }
          }
          if (oldVersion < 17) await createImportFoundationSchema(db);
          if (oldVersion < 18) await createStatementImportProfilesTable(db);
          if (oldVersion < 19) {
            await addColumnIfMissing(
              db,
              'loans',
              'annual_interest_basis_points',
              'INTEGER CHECK(annual_interest_basis_points >= 0)',
            );
            await addColumnIfMissing(
              db,
              'loans',
              'regular_payment_paise',
              'INTEGER CHECK(regular_payment_paise > 0)',
            );
            await addColumnIfMissing(
              db,
              'loans',
              'installment_count',
              'INTEGER CHECK(installment_count > 0)',
            );
            await addColumnIfMissing(db, 'loans', 'first_due_date', 'TEXT');
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

  @override
  Future<int> saveLoan(LoanRecord value) => commitments.saveLoan(value);

  @override
  Future<int> saveLoanWithSchedule(LoanRecord value) =>
      commitments.saveLoanWithSchedule(value);

  @override
  Future<List<LoanRecord>> loans() => commitments.loans();

  @override
  Future<List<LoanTrackingRecord>> loanPayments(int loanId) =>
      commitments.loanPayments(loanId);

  @override
  Future<void> saveLoanPayment(LoanTrackingRecord value) =>
      commitments.saveLoanPayment(value);

  @override
  Future<int> saveEmi(EmiRecord value) => commitments.saveEmi(value);

  @override
  Future<List<EmiRecord>> emis() => commitments.emis();

  @override
  Future<List<EmiInstallment>> emiInstallments(int emiId) =>
      commitments.emiInstallments(emiId);

  @override
  Future<void> saveEmiInstallment({
    int? id,
    required int emiId,
    required int principalPaise,
    required int interestPaise,
    required DateTime date,
    required bool isPaid,
  }) => commitments.saveEmiInstallment(
    id: id,
    emiId: emiId,
    principalPaise: principalPaise,
    interestPaise: interestPaise,
    date: date,
    isPaid: isPaid,
  );

  @override
  Future<int> loadGstBasisPoints() => commitments.loadGstBasisPoints();

  @override
  Future<void> saveGstBasisPoints(int basisPoints) =>
      commitments.saveGstBasisPoints(basisPoints);

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
  Future<List<MoneyTransaction>> transactionsBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async => (await _db.query(
    'transactions',
    where: 'date >= ? AND date < ?',
    whereArgs: [dateTimeKey(startInclusive), dateTimeKey(endExclusive)],
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
  Future<ImportBatchResult> importRecords(List<ImportRecord> records) async {
    var parsed = 0;
    var imported = 0;
    var duplicates = 0;
    var rejected = 0;
    var suggestions = 0;
    await _db.transaction((db) async {
      for (final record in records) {
        final transaction = record.transaction;
        if (transaction != null) parsed++;
        final sameSourceItem = await db.query(
          'import_inbox',
          columns: ['id'],
          where: 'source = ? AND source_item_id = ?',
          whereArgs: [record.source, record.sourceItemId],
          limit: 1,
        );
        if (sameSourceItem.isNotEmpty) {
          duplicates++;
          continue;
        }

        final payloadHash = _stablePayloadHash(record.rawPayload);
        final samePayload = await db.query(
          'import_inbox',
          columns: ['id'],
          where: 'source = ? AND payload_hash = ? AND raw_payload = ?',
          whereArgs: [record.source, payloadHash, record.rawPayload],
          limit: 1,
        );
        if (samePayload.isNotEmpty) {
          await _insertInbox(
            db,
            record,
            payloadHash,
            ImportInboxStatus.duplicate,
            reason: 'same_payload',
          );
          duplicates++;
          continue;
        }
        if (transaction == null) {
          await _insertInbox(
            db,
            record,
            payloadHash,
            ImportInboxStatus.rejected,
            reason: record.rejectionReason ?? 'unsupported_message',
          );
          rejected++;
          continue;
        }
        if (transaction.externalId != null) {
          final existingTransaction = await db.query(
            'transactions',
            columns: ['id'],
            where: 'external_id = ?',
            whereArgs: [transaction.externalId],
            limit: 1,
          );
          if (existingTransaction.isNotEmpty) {
            await _insertInbox(
              db,
              record,
              payloadHash,
              ImportInboxStatus.duplicate,
              reason: 'same_external_id',
              transactionId: existingTransaction.single['id'] as int,
            );
            duplicates++;
            continue;
          }
        }

        final accountId = await _upsertFinancialAccount(db, transaction);
        final inboxId = await _insertInbox(
          db,
          record,
          payloadHash,
          ImportInboxStatus.imported,
          accountId: accountId,
        );
        final transactionId = await writeTransaction(db, transaction);
        await db.update(
          'import_inbox',
          {'transaction_id': transactionId},
          where: 'id = ?',
          whereArgs: [inboxId],
        );
        await db.insert('transaction_provenance', {
          'transaction_id': transactionId,
          'inbox_id': inboxId,
          'source': record.source,
          'source_item_id': record.sourceItemId,
        });
        imported++;
        suggestions += await _suggestReconciliations(
          db,
          transactionId,
          transaction,
        );
      }
    });
    return ImportBatchResult(
      scanned: records.length,
      parsed: parsed,
      imported: imported,
      duplicates: duplicates,
      rejected: rejected,
      reconciliationSuggestions: suggestions,
    );
  }

  Future<int> _insertInbox(
    DatabaseExecutor db,
    ImportRecord record,
    String payloadHash,
    ImportInboxStatus status, {
    String? reason,
    int? transactionId,
    int? accountId,
  }) => db.insert('import_inbox', {
    'source': record.source,
    'source_item_id': record.sourceItemId,
    'payload_hash': payloadHash,
    'raw_payload': record.rawPayload,
    'received_at': record.receivedAt.toIso8601String(),
    'status': status.name,
    'reason': reason,
    'transaction_id': transactionId,
    'account_id': accountId,
  });

  Future<int?> _upsertFinancialAccount(
    DatabaseExecutor db,
    MoneyTransaction transaction,
  ) async {
    final institution = transaction.bankName?.trim();
    final type = transaction.instrumentType;
    if (institution == null || institution.isEmpty || type == null) return null;
    final rows = await db.query(
      'financial_accounts',
      columns: ['id'],
      where: "institution = ? AND instrument_type = ? AND IFNULL(instrument_last4, '') = ?",
      whereArgs: [institution, type.name, transaction.instrumentLast4 ?? ''],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['id'] as int;
    return db.insert('financial_accounts', {
      'institution': institution,
      'instrument_type': type.name,
      'instrument_last4': transaction.instrumentLast4,
      'display_name': transaction.instrumentLabel,
    });
  }

  Future<int> _suggestReconciliations(
    DatabaseExecutor db,
    int transactionId,
    MoneyTransaction transaction,
  ) async {
    final role = transaction.importRole;
    if (role != ImportedTransactionRole.accountDebit &&
        role != ImportedTransactionRole.cardPayment) {
      return 0;
    }
    final counterpart = role == ImportedTransactionRole.accountDebit
        ? ImportedTransactionRole.cardPayment
        : ImportedTransactionRole.accountDebit;
    final candidates = await db.query(
      'transactions',
      columns: ['id', 'date'],
      where: 'id != ? AND import_role = ? AND amount_paise = ?',
      whereArgs: [transactionId, counterpart.name, transaction.amountPaise],
    );
    var count = 0;
    for (final candidate in candidates) {
      final candidateDate = parseTransactionDate(candidate['date'] as String);
      final distance = calendarDate(candidateDate)
          .difference(calendarDate(transaction.date))
          .inDays
          .abs();
      if (distance > 3) continue;
      final candidateId = candidate['id'] as int;
      final debitId = role == ImportedTransactionRole.accountDebit
          ? transactionId
          : candidateId;
      final paymentId = role == ImportedTransactionRole.cardPayment
          ? transactionId
          : candidateId;
      final inserted = await db.insert('import_reconciliations', {
        'account_debit_transaction_id': debitId,
        'card_payment_transaction_id': paymentId,
        'status': ReconciliationStatus.suggested.name,
        'amount_paise': transaction.amountPaise,
        'date_distance_days': distance,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (inserted != 0) count++;
    }
    return count;
  }

  @override
  Future<List<FinancialAccount>> financialAccounts() async =>
      (await _db.query('financial_accounts', orderBy: 'display_name ASC'))
          .map(
            (row) => FinancialAccount(
              id: row['id'] as int,
              institution: row['institution'] as String,
              type: FinancialInstrumentType.values.byName(
                row['instrument_type'] as String,
              ),
              last4: row['instrument_last4'] as String?,
              displayName: row['display_name'] as String,
            ),
          )
          .toList();

  @override
  Future<List<ImportInboxItem>> importInbox({int limit = 100}) async =>
      (await _db.query('import_inbox', orderBy: 'id DESC', limit: limit))
          .map(
            (row) => ImportInboxItem(
              id: row['id'] as int,
              source: row['source'] as String,
              sourceItemId: row['source_item_id'] as String,
              receivedAt: DateTime.parse(row['received_at'] as String),
              status: ImportInboxStatus.values.byName(row['status'] as String),
              reason: row['reason'] as String?,
              transactionId: row['transaction_id'] as int?,
              accountId: row['account_id'] as int?,
            ),
          )
          .toList();

  @override
  Future<List<ImportReconciliation>> importReconciliations() async =>
      (await _db.query('import_reconciliations', orderBy: 'id DESC'))
          .map(
            (row) => ImportReconciliation(
              id: row['id'] as int,
              accountDebitTransactionId:
                  row['account_debit_transaction_id'] as int,
              cardPaymentTransactionId:
                  row['card_payment_transaction_id'] as int,
              status: ReconciliationStatus.values.byName(
                row['status'] as String,
              ),
              amountPaise: row['amount_paise'] as int,
              dateDistanceDays: row['date_distance_days'] as int,
            ),
          )
          .toList();

  @override
  Future<DateTime?> importCursor(String source) async {
    final rows = await _db.query(
      'import_cursors',
      where: 'source = ?',
      whereArgs: [source],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DateTime.parse(rows.single['covered_through'] as String);
  }

  @override
  Future<void> saveImportCursor(String source, DateTime coveredThrough) =>
      _db.insert('import_cursors', {
        'source': source,
        'covered_through': coveredThrough.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> recordImportRun(ImportRunDiagnostic diagnostic) => _db.insert(
    'import_runs',
    {
      'source': diagnostic.source,
      'started_at': diagnostic.startedAt.toIso8601String(),
      'completed_at': diagnostic.completedAt.toIso8601String(),
      'from_at': diagnostic.from.toIso8601String(),
      'until_at': diagnostic.until.toIso8601String(),
      'automatic': diagnostic.automatic ? 1 : 0,
      'scanned': diagnostic.result.scanned,
      'parsed': diagnostic.result.parsed,
      'imported': diagnostic.result.imported,
      'duplicates': diagnostic.result.duplicates,
      'rejected': diagnostic.result.rejected,
      'reconciliation_suggestions': diagnostic.result.reconciliationSuggestions,
      'error_code': diagnostic.errorCode,
    },
  );

  @override
  Future<List<StatementImportProfile>> statementImportProfiles() async =>
      (await _db.query(
        'statement_import_profiles',
        orderBy: 'name ASC',
      )).map(_statementProfileFromRow).toList();

  @override
  Future<int> saveStatementImportProfile(StatementImportProfile profile) async {
    if (profile.name.trim().isEmpty ||
        profile.sourceKey.trim().isEmpty ||
        profile.headerRow < 0) {
      throw ArgumentError('Invalid statement import profile.');
    }
    final row = {
      'name': profile.name.trim(),
      'source_key': profile.sourceKey.trim(),
      'file_format': profile.format.name,
      'sheet_name': profile.sheetName?.trim(),
      'header_row': profile.headerRow,
      'columns_json': jsonEncode({
        for (final entry in profile.columns.entries)
          entry.key.name: entry.value,
      }),
      'defaults_json': jsonEncode({
        for (final entry in profile.defaults.entries)
          entry.key.name: entry.value,
      }),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (profile.id == null) {
      return _db.insert('statement_import_profiles', row);
    }
    final count = await _db.update(
      'statement_import_profiles',
      row,
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    if (count == 0) throw StateError('Import profile no longer exists.');
    return profile.id!;
  }

  @override
  Future<void> deleteStatementImportProfile(int id) =>
      _db.delete('statement_import_profiles', where: 'id = ?', whereArgs: [id]);

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

  /// Writes one transaction using [db] so callers can share an outer transaction.
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
