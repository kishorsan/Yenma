import 'money.dart';

enum ImportInboxStatus { imported, duplicate, rejected }

enum ReconciliationStatus { suggested, confirmed, dismissed }

/// A durable representation of one account or card discovered during import.
class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.institution,
    required this.type,
    required this.last4,
    required this.displayName,
  });

  final int id;
  final String institution;
  final FinancialInstrumentType type;
  final String? last4;
  final String displayName;
}

/// One source item offered to the import pipeline.
///
/// [sourceItemId] is the provider's stable identity. [rawPayload] is retained
/// so duplicate and parser decisions remain auditable.
class ImportRecord {
  const ImportRecord({
    required this.source,
    required this.sourceItemId,
    required this.rawPayload,
    required this.receivedAt,
    this.transaction,
    this.rejectionReason,
  });

  final String source;
  final String sourceItemId;
  final String rawPayload;
  final DateTime receivedAt;
  final MoneyTransaction? transaction;
  final String? rejectionReason;
}

class ImportInboxItem {
  const ImportInboxItem({
    required this.id,
    required this.source,
    required this.sourceItemId,
    required this.receivedAt,
    required this.status,
    this.reason,
    this.transactionId,
    this.accountId,
  });

  final int id;
  final String source;
  final String sourceItemId;
  final DateTime receivedAt;
  final ImportInboxStatus status;
  final String? reason;
  final int? transactionId;
  final int? accountId;
}

class ImportBatchResult {
  const ImportBatchResult({
    required this.scanned,
    required this.parsed,
    required this.imported,
    required this.duplicates,
    required this.rejected,
    required this.reconciliationSuggestions,
  });

  final int scanned;
  final int parsed;
  final int imported;
  final int duplicates;
  final int rejected;
  final int reconciliationSuggestions;
}

class ImportReconciliation {
  const ImportReconciliation({
    required this.id,
    required this.accountDebitTransactionId,
    required this.cardPaymentTransactionId,
    required this.status,
    required this.amountPaise,
    required this.dateDistanceDays,
  });

  final int id;
  final int accountDebitTransactionId;
  final int cardPaymentTransactionId;
  final ReconciliationStatus status;
  final int amountPaise;
  final int dateDistanceDays;
}

class ImportRunDiagnostic {
  const ImportRunDiagnostic({
    required this.source,
    required this.startedAt,
    required this.completedAt,
    required this.from,
    required this.until,
    required this.automatic,
    required this.result,
    this.errorCode,
  });

  final String source;
  final DateTime startedAt;
  final DateTime completedAt;
  final DateTime from;
  final DateTime until;
  final bool automatic;
  final ImportBatchResult result;
  final String? errorCode;
}
