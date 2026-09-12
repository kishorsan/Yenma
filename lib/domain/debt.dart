import 'dart:typed_data';

import 'money.dart';

enum DebtDirection {
  owedToMe('Owed to me'),
  iOwe('I owe');

  const DebtDirection(this.label);
  final String label;
}

class DebtValidationException implements Exception {
  const DebtValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

const maxReceiptBytes = 10 * 1024 * 1024;

String normalizePersonName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ');
String personNameKey(String name) => normalizePersonName(name).toLowerCase();

class DebtDraft {
  const DebtDraft({
    this.id,
    this.transactionId,
    required this.person,
    required this.title,
    required this.amountPaise,
    required this.direction,
    required this.date,
    this.note = '',
    this.receipt,
    this.removeReceipt = false,
  });
  final int? id;
  final int? transactionId;
  final String person;
  final String title;
  final int amountPaise;
  final DebtDirection direction;
  final DateTime date;
  final String note;
  final Uint8List? receipt;
  final bool removeReceipt;

  DebtDraft linkedTo(int transactionId) => DebtDraft(
    id: id,
    transactionId: transactionId,
    person: person,
    title: title,
    amountPaise: amountPaise,
    direction: direction,
    date: date,
    note: note,
    receipt: receipt,
    removeReceipt: removeReceipt,
  );
}

class DebtRecord {
  const DebtRecord({
    required this.id,
    this.transactionId,
    required this.person,
    required this.title,
    required this.amountPaise,
    required this.repaidPaise,
    required this.direction,
    required this.date,
    required this.note,
    required this.hasReceipt,
  });
  final int id;
  final int? transactionId;
  final String person;
  final String title;
  final int amountPaise;
  final int repaidPaise;
  final DebtDirection direction;
  final DateTime date;
  final String note;
  final bool hasReceipt;
  int get remainingPaise => amountPaise - repaidPaise;
  bool get isSettled => remainingPaise == 0;
  String get personKey =>
      person.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  factory DebtRecord.fromRow(Map<String, Object?> row) => DebtRecord(
    id: row['id'] as int,
    transactionId: row['transaction_id'] as int?,
    person: row['person'] as String,
    title: row['title'] as String,
    amountPaise: row['amount_paise'] as int,
    repaidPaise: row['repaid_paise'] as int,
    direction: DebtDirection.values.byName(row['direction'] as String),
    date: DateTime.parse(row['date'] as String),
    note: row['note'] as String,
    hasReceipt: row['has_receipt'] == 1,
  );
}

class Repayment {
  const Repayment({
    required this.id,
    required this.debtId,
    required this.amountPaise,
    required this.date,
    required this.note,
  });
  final int id;
  final int debtId;
  final int amountPaise;
  final DateTime date;
  final String note;
  factory Repayment.fromRow(Map<String, Object?> row) => Repayment(
    id: row['id'] as int,
    debtId: row['debt_id'] as int,
    amountPaise: row['amount_paise'] as int,
    date: DateTime.parse(row['date'] as String),
    note: row['note'] as String,
  );
}

abstract interface class DebtRepository {
  Future<List<String>> people();
  Future<List<DebtRecord>> debts();
  Future<void> saveDebt(DebtDraft draft);
  Future<void> saveSharedExpense(MoneyTransaction transaction, DebtDraft draft);
  Future<int> saveSharedExpenses(MoneyTransaction transaction, List<DebtDraft> drafts);
  Future<void> deleteDebt(int id);
  Future<Uint8List?> debtReceipt(int id);
  Future<List<Repayment>> repayments(int debtId);
  Future<void> addRepayment(
    int debtId,
    int amountPaise,
    DateTime date,
    String note,
  );
  Future<void> deleteRepayment(int id);
  Future<MoneyTransaction?> transactionById(int id);
}
