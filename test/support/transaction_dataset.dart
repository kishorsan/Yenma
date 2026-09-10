import 'package:yenma/domain/money.dart';

/// Synthetic fixtures only: never imported by lib/ or bundled as assets.
/// Includes seven previous days, today, and seven following days.
List<MoneyTransaction> transactionDataset(DateTime anchor) => [
  for (var offset = -7; offset <= 7; offset++)
    for (final sample in [
      ('Lunch', 50000, TransactionKind.expense, 1),
      ('Bus commute', 6000, TransactionKind.expense, 3),
      ('Groceries', 85000, TransactionKind.expense, 2),
      ('Freelance payment', 120000, TransactionKind.income, 13),
      ('Savings transfer', 20000, TransactionKind.transfer, 12),
    ])
      MoneyTransaction(
        title: '${sample.$1} day $offset',
        amountPaise: sample.$2,
        kind: sample.$3,
        categoryId: sample.$4,
        date: DateTime(anchor.year, anchor.month, anchor.day + offset),
        note: 'Synthetic test data',
      ),
];
