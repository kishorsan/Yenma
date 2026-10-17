import '../data/money_repository.dart';
import '../domain/money.dart';

/// Creates income, bank-account and credit-card transactions across three months.
Future<void> seedTransactionPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  const seeds = <PreviewTransactionSeed>[
    PreviewTransactionSeed('Lunch at Meghana Foods', 48500, 1, 0),
    PreviewTransactionSeed('Chai and evening snacks', 14500, 1, 1),
    PreviewTransactionSeed('Zudio clothes', 289900, 4, 3),
    PreviewTransactionSeed('Uber ride', 37800, 3, 5),
    PreviewTransactionSeed('Reliance Fresh', 176450, 2, 7),
    PreviewTransactionSeed('Amazon electronics', 649900, 4, 9),
    PreviewTransactionSeed('Netflix', 64900, 8, 11),
    PreviewTransactionSeed('Office lunch', 32000, 1, 13),
    PreviewTransactionSeed('Apollo Pharmacy', 87500, 5, 15),
    PreviewTransactionSeed('Electricity bill', 214500, 7, 17),
    PreviewTransactionSeed('Weekend movie', 74000, 6, 19),
    PreviewTransactionSeed('Indian Oil', 250000, 3, 21),
    PreviewTransactionSeed(
      'Monthly salary',
      7200000,
      10,
      23,
      kind: TransactionKind.income,
    ),
    PreviewTransactionSeed('House rent', 1800000, 14, 24),
    PreviewTransactionSeed('Swiggy dinner', 62000, 1, 26),
    PreviewTransactionSeed('More supermarket', 223600, 2, 28),
    PreviewTransactionSeed('Spotify', 11900, 8, 30),
    PreviewTransactionSeed('Metro card recharge', 100000, 3, 32),
    PreviewTransactionSeed('Myntra clothes', 199900, 4, 34),
    PreviewTransactionSeed('Breakfast and coffee', 23500, 1, 36),
    PreviewTransactionSeed('Mobile recharge', 74900, 7, 38),
    PreviewTransactionSeed('Bookstore', 89900, 9, 40),
    PreviewTransactionSeed('Dinner with friends', 184000, 1, 42),
    PreviewTransactionSeed('Dental consultation', 120000, 5, 44),
    PreviewTransactionSeed(
      'Monthly salary',
      7200000,
      10,
      47,
      kind: TransactionKind.income,
    ),
    PreviewTransactionSeed('House rent', 1800000, 14, 48),
    PreviewTransactionSeed('Laptop accessories', 229900, 4, 50),
    PreviewTransactionSeed('BigBasket groceries', 268750, 2, 52),
    PreviewTransactionSeed('Auto ride', 18000, 3, 54),
    PreviewTransactionSeed('Lunch thali', 28000, 1, 56),
    PreviewTransactionSeed('Internet bill', 117800, 7, 58),
    PreviewTransactionSeed('Bakery snacks', 19500, 1, 61),
  ];

  await repository.importTransactions([
    for (var index = 0; index < seeds.length; index++)
      _previewTransaction(
        title: seeds[index].title,
        amountPaise: seeds[index].amountPaise,
        categoryId: seeds[index].categoryId,
        kind: seeds[index].kind,
        date: anchor.subtract(Duration(days: seeds[index].daysAgo)),
        sequence: index,
        bankName: index % 5 == 2 ? 'ICICI Credit Card' : 'HDFC Bank',
      ),
  ]);
}

/// Compact definition used to generate deterministic transaction fixtures.
class PreviewTransactionSeed {
  const PreviewTransactionSeed(
    this.title,
    this.amountPaise,
    this.categoryId,
    this.daysAgo, {
    this.kind = TransactionKind.expense,
  });

  final String title;
  final int amountPaise;
  final int categoryId;
  final int daysAgo;
  final TransactionKind kind;
}

MoneyTransaction _previewTransaction({
  required String title,
  required int amountPaise,
  required int categoryId,
  required DateTime date,
  required int sequence,
  required String bankName,
  TransactionKind kind = TransactionKind.expense,
}) => MoneyTransaction(
  title: title,
  amountPaise: amountPaise,
  kind: kind,
  categoryId: categoryId,
  date: DateTime(date.year, date.month, date.day, 12),
  source: 'SMS',
  bankName: bankName,
  instrumentType: bankName.toLowerCase().contains('credit card')
      ? FinancialInstrumentType.creditCard
      : FinancialInstrumentType.bankAccount,
  externalId: 'preview-v3-${dateKey(date)}-$sequence',
  recipientKey: transactionNameKey(title),
  note: 'Preview fixture',
);
