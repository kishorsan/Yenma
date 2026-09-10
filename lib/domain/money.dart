import 'package:intl/intl.dart';

enum TransactionKind {
  expense('Expense'),
  income('Income'),
  transfer('Transfer');

  const TransactionKind(this.label);
  final String label;
}

// INR input never passes through binary floating point.
int? parsePaise(String value) {
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final paise =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  return paise > 0 ? paise : null;
}

String formatMoney(int paise) {
  final sign = paise < 0 ? '−' : '';
  final absolute = paise.abs();
  return '$sign₹${NumberFormat.decimalPattern('en_IN').format(absolute ~/ 100)}.${(absolute % 100).toString().padLeft(2, '0')}';
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class MoneyCategory {
  const MoneyCategory(this.id, this.name, this.icon, this.color, this.kinds);
  final int id;
  final String name;
  final String icon;
  final int color;
  final Set<TransactionKind> kinds;
}

const _expense = {TransactionKind.expense};
const defaultCategories = <MoneyCategory>[
  MoneyCategory(1, 'Food', 'restaurant', 0xFFFF9F43, _expense),
  MoneyCategory(2, 'Groceries', 'shopping_cart', 0xFF26DE81, _expense),
  MoneyCategory(3, 'Transport', 'directions_car', 0xFF54A0FF, _expense),
  MoneyCategory(4, 'Shopping', 'shopping_bag', 0xFFFF6B9D, _expense),
  MoneyCategory(5, 'Health', 'local_hospital', 0xFFA29BFE, _expense),
  MoneyCategory(6, 'Entertainment', 'movie', 0xFFFF6348, _expense),
  MoneyCategory(7, 'Bills', 'receipt', 0xFF778CA3, _expense),
  MoneyCategory(8, 'Subscriptions', 'subscriptions', 0xFFD4A9FF, _expense),
  MoneyCategory(9, 'Education', 'school', 0xFF45AAF2, _expense),
  MoneyCategory(10, 'Salary', 'account_balance', 0xFF00E5A0, {
    TransactionKind.income,
  }),
  MoneyCategory(11, 'Investment', 'trending_up', 0xFF26DE81, {
    TransactionKind.income,
  }),
  MoneyCategory(12, 'Transfer', 'swap_horiz', 0xFF54A0FF, {
    TransactionKind.transfer,
  }),
  MoneyCategory(13, 'Other', 'more_horiz', 0xFF8A9BB0, {
    TransactionKind.expense,
    TransactionKind.income,
  }),
];

class MoneyTransaction {
  const MoneyTransaction({
    this.id,
    required this.title,
    required this.amountPaise,
    required this.kind,
    required this.categoryId,
    required this.date,
    this.note = '',
  });
  final int? id;
  final String title;
  final int amountPaise;
  final TransactionKind kind;
  final int categoryId;
  final DateTime date;
  final String note;

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'title': title.trim(),
    'amount_paise': amountPaise,
    'kind': kind.name,
    'category_id': categoryId,
    'date': dateKey(date),
    'note': note.trim(),
  };

  factory MoneyTransaction.fromRow(Map<String, Object?> row) =>
      MoneyTransaction(
        id: row['id'] as int,
        title: row['title'] as String,
        amountPaise: row['amount_paise'] as int,
        kind: TransactionKind.values.byName(row['kind'] as String),
        categoryId: row['category_id'] as int,
        date: DateTime.parse(row['date'] as String),
        note: row['note'] as String,
      );
}

class MonthSummary {
  MonthSummary(Iterable<MoneyTransaction> transactions) {
    for (final transaction in transactions) {
      switch (transaction.kind) {
        case TransactionKind.expense:
          expense += transaction.amountPaise;
          byCategory.update(
            transaction.categoryId,
            (value) => value + transaction.amountPaise,
            ifAbsent: () => transaction.amountPaise,
          );
        case TransactionKind.income:
          income += transaction.amountPaise;
        case TransactionKind.transfer:
          transfer += transaction.amountPaise;
      }
    }
  }
  int income = 0;
  int expense = 0;
  int transfer = 0;
  int get net => income - expense;
  final Map<int, int> byCategory = {};
}
