import 'dart:typed_data';

import '../../domain/debt.dart';
import '../../domain/money.dart';
import '../../domain/monthly_plan.dart';
import '../../domain/split.dart';
import '../../domain/import_foundation.dart';
import '../../domain/statement_import.dart';
import '../commitments/repository_contracts.dart';

/// Application-facing contract for all persisted money features.
///
/// Feature-specific contracts are composed here so controllers can depend on
/// one storage boundary without knowing that SQLite is the implementation.
abstract interface class MoneyRepository
    implements
        DebtRepository,
        SplitRepository,
        SubscriptionRepository,
        EmiRepository,
        LoanRepository {
  /// Opens the database and applies all required schema migrations.
  Future<void> initialize();

  /// Loads the category catalogue used by transaction forms and summaries.
  Future<List<MoneyCategory>> categories();

  /// Loads transactions occurring in the calendar month containing [month].
  Future<List<MoneyTransaction>> transactions(DateTime month);

  /// Loads transactions in the half-open interval `[startInclusive, endExclusive)`.
  Future<List<MoneyTransaction>> transactionsBetween(
    DateTime startInclusive,
    DateTime endExclusive,
  );

  /// Inserts or updates one manually entered or imported transaction.
  Future<void> save(MoneyTransaction transaction);

  /// Loads normalized plans for the calendar month containing [month].
  Future<List<MoneyPlan>> plansForMonth(DateTime month);

  /// Loads reusable plan-type suggestions.
  Future<List<PlanType>> planTypes();

  /// Inserts or updates one monthly plan.
  Future<void> savePlan(MoneyPlan plan);

  /// Applies [categoryId] to the supplied persisted transactions atomically.
  Future<void> bulkCategorize(
    List<MoneyTransaction> transactions,
    int categoryId,
  );

  /// Imports transactions while ignoring duplicate external identifiers.
  Future<int> importTransactions(List<MoneyTransaction> transactions);

  /// Stages source records, applies exact deduplication, creates ledger rows,
  /// and records provenance and safe reconciliation suggestions atomically.
  Future<ImportBatchResult> importRecords(List<ImportRecord> records);

  Future<List<FinancialAccount>> financialAccounts();

  Future<List<ImportInboxItem>> importInbox({int limit = 100});

  Future<List<ImportReconciliation>> importReconciliations();

  /// Returns the exclusive end of the interval successfully covered by source.
  Future<DateTime?> importCursor(String source);

  Future<void> saveImportCursor(String source, DateTime coveredThrough);

  Future<void> recordImportRun(ImportRunDiagnostic diagnostic);

  Future<List<StatementImportProfile>> statementImportProfiles();

  Future<int> saveStatementImportProfile(StatementImportProfile profile);

  Future<void> deleteStatementImportProfile(int id);

  /// Returns the learned category for a normalized recipient key.
  Future<int?> categoryForRecipient(String recipientKey);

  /// Remembers a category selection for future imports from a recipient.
  Future<void> saveRecipientCategory(String recipientKey, int categoryId);

  /// Replaces the chunked receipt attached to [transactionId].
  Future<void> saveTransactionReceipt(int transactionId, Uint8List bytes);

  /// Reassembles and returns the receipt attached to [transactionId].
  Future<Uint8List?> transactionReceipt(int transactionId);

  /// Removes the receipt attached to [transactionId].
  Future<void> deleteTransactionReceipt(int transactionId);

  /// Reports whether an SMS sync marker exists for the supplied calendar date.
  Future<bool> wasSyncedOn(DateTime date);

  /// Records that SMS synchronization ran on the supplied calendar date.
  Future<void> markSynced(DateTime date);

  /// Returns the timestamp of the latest completed SMS synchronization.
  Future<DateTime?> lastSmsSyncAt();

  /// Appends an SMS synchronization diagnostic record.
  Future<void> recordSmsSync({
    required DateTime completedAt,
    required int imported,
    required bool automatic,
  });

  /// Deletes a transaction and any application-managed dependent data.
  Future<void> delete(int id);

  /// Loads the stored application theme preference.
  Future<String> loadTheme();

  /// Stores the application theme preference.
  Future<void> saveTheme(String theme);

  /// Reports whether the user granted SMS import consent.
  Future<bool> loadSmsConsent();

  /// Stores the user's SMS import consent choice.
  Future<void> saveSmsConsent(bool granted);

  /// Reports whether the initial historical SMS import has completed.
  Future<bool> loadInitialSmsSyncComplete();

  /// Marks the initial historical SMS import as complete.
  Future<void> saveInitialSmsSyncComplete();

  /// Releases the open database connection.
  Future<void> close();
}
