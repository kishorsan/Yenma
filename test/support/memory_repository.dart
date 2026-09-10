import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/domain/debt.dart';

import 'dart:typed_data';

class MemoryRepository implements MoneyRepository {
  final List<MoneyTransaction> entries = [];
  String theme = 'system';
  bool failSave = false;
  int _id = 0;
  int _debtId = 0;
  int _repaymentId = 0;
  final _debts = <int, DebtDraft>{};
  final _receipts = <int, Uint8List>{};
  final _repayments = <Repayment>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<List<MoneyCategory>> categories() async => defaultCategories;
  @override
  Future<List<MoneyTransaction>> transactions(DateTime month) async =>
      entries
          .where(
            (entry) =>
                entry.date.year == month.year &&
                entry.date.month == month.month,
          )
          .toList()
        ..sort((a, b) {
          final date = b.date.compareTo(a.date);
          return date == 0 ? b.id!.compareTo(a.id!) : date;
        });
  @override
  Future<void> save(MoneyTransaction transaction) async {
    if (failSave) throw StateError('Disk full');
    final id = transaction.id ?? ++_id;
    entries.removeWhere((entry) => entry.id == id);
    entries.add(
      MoneyTransaction(
        id: id,
        title: transaction.title.trim(),
        amountPaise: transaction.amountPaise,
        kind: transaction.kind,
        categoryId: transaction.categoryId,
        date: transaction.date,
        note: transaction.note,
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<String> loadTheme() async => theme;
  @override
  Future<void> saveTheme(String theme) async {
    this.theme = theme;
  }

  @override
  Future<void> close() async {}

  @override
  Future<List<DebtRecord>> debts() async => _debts.entries.map((entry) {
    final d = entry.value;
    return DebtRecord(
      id: entry.key,
      transactionId: d.transactionId,
      person: d.person,
      title: d.title,
      amountPaise: d.amountPaise,
      repaidPaise: _repayments
          .where((r) => r.debtId == entry.key)
          .fold(0, (sum, r) => sum + r.amountPaise),
      direction: d.direction,
      date: d.date,
      note: d.note,
      hasReceipt: _receipts.containsKey(entry.key),
    );
  }).toList();
  @override
  Future<void> saveDebt(DebtDraft draft) async {
    if (failSave) throw StateError('Disk full');
    final id = draft.id ?? ++_debtId;
    _debts[id] = draft;
    if (draft.removeReceipt) {
      _receipts.remove(id);
    } else if (draft.receipt != null) {
      _receipts[id] = draft.receipt!;
    }
  }

  @override
  Future<void> saveSharedExpense(
    MoneyTransaction transaction,
    DebtDraft draft,
  ) async {
    await save(transaction);
    await saveDebt(draft.linkedTo(entries.last.id!));
  }

  @override
  Future<void> deleteDebt(int id) async {
    _debts.remove(id);
    _receipts.remove(id);
    _repayments.removeWhere((r) => r.debtId == id);
  }

  @override
  Future<Uint8List?> debtReceipt(int id) async => _receipts[id];
  @override
  Future<List<Repayment>> repayments(int debtId) async =>
      _repayments.where((r) => r.debtId == debtId).toList();
  @override
  Future<void> addRepayment(
    int debtId,
    int amountPaise,
    DateTime date,
    String note,
  ) async {
    if (failSave) throw StateError('Disk full');
    _repayments.add(
      Repayment(
        id: ++_repaymentId,
        debtId: debtId,
        amountPaise: amountPaise,
        date: date,
        note: note,
      ),
    );
  }

  @override
  Future<void> deleteRepayment(int id) async {
    _repayments.removeWhere((r) => r.id == id);
  }

  @override
  Future<MoneyTransaction?> transactionById(int id) async =>
      entries.where((t) => t.id == id).firstOrNull;
}
