import 'import_foundation.dart';

enum StatementFileFormat { csv, xlsx }

enum StatementField {
  sourceRecordId,
  transactionDate,
  description,
  amount,
  debitAmount,
  creditAmount,
  transactionType,
  institution,
  instrumentType,
  instrumentLast4,
  currency,
  category,
  reference,
  note,
}

/// Saved mapping from one statement layout into Yenma's canonical fields.
class StatementImportProfile {
  const StatementImportProfile({
    this.id,
    required this.name,
    required this.sourceKey,
    required this.format,
    required this.columns,
    this.defaults = const {},
    this.sheetName,
    this.headerRow = 0,
  });

  final int? id;
  final String name;
  final String sourceKey;
  final StatementFileFormat format;
  final Map<StatementField, String> columns;
  final Map<StatementField, String> defaults;
  final String? sheetName;
  final int headerRow;

  static const canonical = StatementImportProfile(
    name: 'Yenma template',
    sourceKey: 'yenma-template-v1',
    format: StatementFileFormat.xlsx,
    sheetName: 'Transactions',
    headerRow: 4,
    columns: {
      StatementField.sourceRecordId: 'source_record_id',
      StatementField.transactionDate: 'transaction_date',
      StatementField.description: 'description',
      StatementField.amount: 'amount_inr',
      StatementField.transactionType: 'transaction_type',
      StatementField.institution: 'institution',
      StatementField.instrumentType: 'instrument_type',
      StatementField.instrumentLast4: 'instrument_last4',
      StatementField.currency: 'currency',
      StatementField.category: 'category',
      StatementField.reference: 'reference',
      StatementField.note: 'note',
    },
    defaults: {StatementField.currency: 'INR'},
  );
}

class StatementRowIssue {
  const StatementRowIssue({
    required this.rowNumber,
    required this.code,
    required this.message,
  });

  final int rowNumber;
  final String code;
  final String message;
}

class StatementParseResult {
  const StatementParseResult({required this.records, required this.issues});

  final List<ImportRecord> records;
  final List<StatementRowIssue> issues;
}
