import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/data/statement_import.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/domain/statement_import.dart';

void main() {
  const decoder = StatementWorkbookDecoder();
  const adapter = StatementImportAdapter();

  test('default workbook exposes the canonical Yenma columns', () async {
    final bytes = await File('assets/templates/Yenma-Transaction-Import.xlsx')
        .readAsBytes();

    final decoded = decoder.decode(bytes, StatementImportProfile.canonical);
    final parsed = adapter.parse(
      decoded,
      StatementImportProfile.canonical,
      receivedAt: DateTime(2026, 10, 16),
    );

    expect(decoded.headers, [
      'source_record_id',
      'transaction_date',
      'description',
      'amount_inr',
      'transaction_type',
      'institution',
      'instrument_type',
      'instrument_last4',
      'currency',
      'category',
      'reference',
      'note',
    ]);
    expect(parsed.records, isEmpty);
    expect(parsed.issues, isEmpty);
  });

  test(
    'XLSX reader imports typed dates and amounts from example rows',
    () async {
      final bytes = await File('assets/templates/Yenma-Transaction-Import.xlsx')
          .readAsBytes();
      final profile = StatementImportProfile(
        name: 'Template examples',
        sourceKey: 'template-examples',
        format: StatementFileFormat.xlsx,
        sheetName: 'Reference',
        headerRow: 23,
        columns: StatementImportProfile.canonical.columns,
        defaults: StatementImportProfile.canonical.defaults,
      );

      final result = adapter.parse(
        decoder.decode(bytes, profile),
        profile,
        receivedAt: DateTime(2026, 10, 16),
      );

      expect(result.issues, isEmpty);
      expect(result.records, hasLength(3));
      expect(result.records.first.transaction!.date, DateTime(2026, 10, 15));
      expect(result.records.first.transaction!.amountPaise, 12550);
      expect(result.records.last.transaction!.kind, TransactionKind.transfer);
    },
  );

  test('custom CSV mapping infers debit and credit transaction kinds', () {
    final bytes = Uint8List.fromList(
      '''Txn Id,Posted,Narration,Debit,Credit
CB-1,15/10/2026,Corner Cafe,125.50,
CB-2,16/10/2026,Salary,,85000
'''
          .codeUnits,
    );
    const profile = StatementImportProfile(
      name: 'Canara transformed CSV',
      sourceKey: 'canara-primary-1234',
      format: StatementFileFormat.csv,
      columns: {
        StatementField.sourceRecordId: 'Txn Id',
        StatementField.transactionDate: 'Posted',
        StatementField.description: 'Narration',
        StatementField.debitAmount: 'Debit',
        StatementField.creditAmount: 'Credit',
      },
      defaults: {
        StatementField.institution: 'Canara Bank',
        StatementField.instrumentType: 'Bank Account',
        StatementField.instrumentLast4: '1234',
        StatementField.currency: 'INR',
      },
    );

    final result = adapter.parse(
      decoder.decode(bytes, profile),
      profile,
      receivedAt: DateTime(2026, 10, 16),
    );

    expect(result.issues, isEmpty);
    expect(result.records, hasLength(2));
    expect(result.records.first.transaction!.kind, TransactionKind.expense);
    expect(result.records.first.transaction!.amountPaise, 12550);
    expect(result.records.last.transaction!.kind, TransactionKind.income);
    expect(result.records.last.transaction!.amountPaise, 8500000);
    expect(
      result.records.first.transaction!.externalId,
      'statement:canara-primary-1234:CB-1',
    );
  });

  test('invalid rows remain available as rejected inbox records', () {
    final bytes = Uint8List.fromList(
      '''id,date,title,amount,type,bank,instrument,currency
1,2026-10-15,Coffee,100,Expense,HDFC Bank,Bank Account,USD
'''
          .codeUnits,
    );
    const profile = StatementImportProfile(
      name: 'Invalid sample',
      sourceKey: 'invalid-sample',
      format: StatementFileFormat.csv,
      columns: {
        StatementField.sourceRecordId: 'id',
        StatementField.transactionDate: 'date',
        StatementField.description: 'title',
        StatementField.amount: 'amount',
        StatementField.transactionType: 'type',
        StatementField.institution: 'bank',
        StatementField.instrumentType: 'instrument',
        StatementField.currency: 'currency',
      },
    );

    final result = adapter.parse(decoder.decode(bytes, profile), profile);

    expect(result.issues.single.code, 'unsupported_currency');
    expect(result.records.single.transaction, isNull);
    expect(result.records.single.rejectionReason, 'unsupported_currency');
  });
}
