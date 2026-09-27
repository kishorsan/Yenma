import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/domain/money.dart';

void main() {
  test('decimal amounts are converted exactly and invalid inputs rejected', () {
    expect(parsePaise('0.10')! + parsePaise('0.20')!, 30);
    expect(parsePaise(' 125.5 '), 12550);
    expect(parsePaise('9999999999.99'), 999999999999);
    for (final input in [
      '',
      '0',
      '-1',
      '1.234',
      '1e3',
      'NaN',
      '1,000',
      '10000000000',
      '.',
    ]) {
      expect(parsePaise(input), isNull, reason: input);
    }
    expect(formatMoney(12345678), '₹1,23,456.78');
    expect(formatMoney(-10), '−₹0.10');
  });

  test('only expenses contribute to spending and category totals', () {
    final summary = MonthSummary([
      MoneyTransaction(
        title: 'Lunch',
        amountPaise: 10000,
        kind: TransactionKind.expense,
        categoryId: 1,
        date: DateTime(2026, 9, 10),
      ),
      MoneyTransaction(
        title: 'Salary',
        amountPaise: 50000,
        kind: TransactionKind.income,
        categoryId: 10,
        date: DateTime(2026, 9, 10),
      ),
      MoneyTransaction(
        title: 'Transfer',
        amountPaise: 20000,
        kind: TransactionKind.transfer,
        categoryId: 12,
        date: DateTime(2026, 9, 10),
      ),
    ]);
    expect(summary.expense, 10000);
    expect(summary.income, 50000);
    expect(summary.transfer, 20000);
    expect(summary.net, 40000);
    expect(summary.byCategory, {1: 10000});
    expect(MonthSummary([]).net, 0);
  });
  test('calendar dates retain leap day without timestamp conversion', () {
    expect(dateKey(DateTime(2024, 2, 29, 23, 59)), '2024-02-29');
  });

  test('transaction timestamps are sortable and date-only values use noon', () {
    expect(
      dateTimeKey(DateTime(2026, 9, 10, 7, 5, 4, 3)),
      '2026-09-10T07:05:04.003',
    );
    expect(parseTransactionDate('2026-09-10'), DateTime(2026, 9, 10, 12));
    expect(
      parseTransactionDate('2026-09-10T18:30:00.000'),
      DateTime(2026, 9, 10, 18, 30),
    );
  });

  test('matching transaction names ignore case and repeated whitespace', () {
    expect(transactionNameKey('  ACME   Store '), 'acme store');
    expect(
      transactionNameKey('ACME Store'),
      transactionNameKey(' acme  store '),
    );
  });

  test('name matching groups the same transaction type only', () {
    MoneyTransaction transaction(int id, String title, TransactionKind kind) =>
        MoneyTransaction(
          id: id,
          title: title,
          amountPaise: 100,
          kind: kind,
          categoryId: kind == TransactionKind.income ? 15 : 13,
          date: DateTime(2026, 9, 10),
        );
    final target = transaction(1, 'ACME Store', TransactionKind.expense);
    final matches = transactionsMatchingName(
      [
        target,
        transaction(2, ' acme  store ', TransactionKind.expense),
        transaction(3, 'ACME Store', TransactionKind.income),
        transaction(4, 'Different', TransactionKind.expense),
      ],
      target,
    );
    expect(matches.map((item) => item.id), [1, 2]);
  });

  test('new expense and income categories support the intended kinds', () {
    final rent = defaultCategories.singleWhere((item) => item.name == 'Rent');
    final received = defaultCategories.singleWhere(
      (item) => item.name == 'Received',
    );
    final wallet = defaultCategories.singleWhere(
      (item) => item.name == 'Wallet',
    );
    final savings = defaultCategories.singleWhere(
      (item) => item.name == 'Savings',
    );
    expect(rent.kinds, {TransactionKind.expense});
    expect(received.kinds, {TransactionKind.income});
    expect(wallet.kinds, {TransactionKind.expense});
    expect(savings.kinds, {TransactionKind.expense});
  });
}
