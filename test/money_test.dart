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
}
