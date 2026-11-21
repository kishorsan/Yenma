import '../data/money_repository.dart';
import '../models/reference_data/bank_record.dart';

/// Creates the bank and card references used by transaction preview fixtures.
Future<void> seedReferencePreviewData(SqliteMoneyRepository repository) async {
  await repository.referenceData.saveBank(
    const BankRecord(name: 'HDFC Bank', code: 'HDFC'),
  );
  await repository.referenceData.saveBank(
    const BankRecord(
      name: 'ICICI Credit Card',
      code: 'ICICI_CC',
      isCreditCard: true,
    ),
  );
}
