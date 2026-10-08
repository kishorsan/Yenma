import 'package:intl/intl.dart';

enum TransactionKind {
  expense('Expense'),
  income('Income'),
  transfer('Transfer');

  const TransactionKind(this.label);
  final String label;
}

enum FinancialInstrumentType { bankAccount, creditCard }

enum ImportedTransactionRole {
  cardPurchase,
  accountDebit,
  accountCredit,
  cardPayment,
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
String dateTimeKey(DateTime date) =>
    '${dateKey(date)}T${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}:'
    '${date.second.toString().padLeft(2, '0')}.'
    '${date.millisecond.toString().padLeft(3, '0')}';

DateTime parseTransactionDate(String value) {
  final parsed = DateTime.parse(value);
  return value.contains('T') || value.contains(' ')
      ? parsed
      : DateTime(parsed.year, parsed.month, parsed.day, 12);
}

DateTime calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String transactionNameKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

Iterable<MoneyTransaction> transactionsMatchingName(
  Iterable<MoneyTransaction> candidates,
  MoneyTransaction target,
) => candidates.where(
  (candidate) =>
      candidate.kind == target.kind &&
      transactionNameKey(candidate.title) == transactionNameKey(target.title),
);

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
  MoneyCategory(14, 'Rent', 'home', 0xFF7C6CF2, _expense),
  MoneyCategory(15, 'Received', 'call_received', 0xFF20BF6B, {
    TransactionKind.income,
  }),
  MoneyCategory(16, 'Wallet', 'account_balance_wallet', 0xFFF7B731, _expense),
  MoneyCategory(17, 'Savings', 'savings', 0xFF2D98DA, _expense),
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
    this.source = 'MANUAL',
    this.bankName,
    this.instrumentType,
    this.instrumentLast4,
    this.importRole,
    this.externalId,
    this.recipientKey,
    this.hasReceipt = false,
  });
  final int? id;
  final String title;
  final int amountPaise;
  final TransactionKind kind;
  final int categoryId;
  final DateTime date;
  final String note;
  final String source;
  final String? bankName;
  final FinancialInstrumentType? instrumentType;
  final String? instrumentLast4;
  final ImportedTransactionRole? importRole;
  final String? externalId;
  final String? recipientKey;
  final bool hasReceipt;

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'title': title.trim(),
    'amount_paise': amountPaise,
    'kind': kind.name,
    'category_id': categoryId,
    'date': dateTimeKey(date),
    'note': note.trim(),
    'source': source,
    'bank_name': bankName,
    if (instrumentType != null) 'instrument_type': instrumentType!.name,
    if (instrumentLast4 != null) 'instrument_last4': instrumentLast4,
    if (importRole != null) 'import_role': importRole!.name,
    'external_id': externalId,
    'recipient_key': recipientKey,
  };

  factory MoneyTransaction.fromRow(Map<String, Object?> row) =>
      MoneyTransaction(
        id: row['id'] as int,
        title: row['title'] as String,
        amountPaise: row['amount_paise'] as int,
        kind: TransactionKind.values.byName(row['kind'] as String),
        categoryId: row['category_id'] as int,
        date: parseTransactionDate(row['date'] as String),
        note: row['note'] as String,
        source: (row['source'] as String?) ?? 'MANUAL',
        bankName: row['bank_name'] as String?,
        instrumentType: row['instrument_type'] == null
            ? null
            : FinancialInstrumentType.values.byName(
                row['instrument_type'] as String,
              ),
        instrumentLast4: row['instrument_last4'] as String?,
        importRole: row['import_role'] == null
            ? null
            : ImportedTransactionRole.values.byName(
                row['import_role'] as String,
              ),
        externalId: row['external_id'] as String?,
        recipientKey: row['recipient_key'] as String?,
        hasReceipt: row['has_receipt'] == 1,
      );

  bool get isCreditCard =>
      instrumentType == FinancialInstrumentType.creditCard ||
      (instrumentType == null &&
          (bankName?.toLowerCase().contains('credit card') ?? false));

  String get instrumentLabel {
    final institution = bankName?.trim();
    final base = institution == null || institution.isEmpty
        ? (isCreditCard ? 'Credit card' : 'Bank account')
        : institution;
    final suffix = instrumentLast4?.trim();
    return suffix == null || suffix.isEmpty ? base : '$base •$suffix';
  }
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
