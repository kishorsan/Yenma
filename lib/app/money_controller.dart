import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../data/money_repository.dart';
import '../domain/money.dart';
import '../domain/debt.dart';
import '../data/receipt_source.dart';

class MoneyController extends ChangeNotifier {
  MoneyController(this.repository, {ReceiptSource? receipts})
    : receipts = receipts ?? ImageReceiptSource();
  final MoneyRepository repository;
  final ReceiptSource receipts;
  List<DebtRecord> debts = [];
  List<String> people = [];
  bool debtsLoading = false;
  String? debtError;
  Uint8List? recoveredReceipt;
  String? receiptRecoveryError;
  int _debtGeneration = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<MoneyCategory> categories = [];
  List<MoneyTransaction> transactions = [];
  ThemeMode themeMode = ThemeMode.system;
  bool initializing = true;
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    initializing = true;
    error = null;
    _emit();
    try {
      await repository.initialize();
      categories = await repository.categories();
      final theme = await repository.loadTheme();
      themeMode =
          ThemeMode.values.where((mode) => mode.name == theme).firstOrNull ??
          ThemeMode.system;
      await loadMonth(month);
      await loadDebts();
    } catch (_) {
      error = 'Your local data could not be opened. Please try again.';
    } finally {
      initializing = false;
      _emit();
    }
  }

  Future<void> loadMonth(DateTime selected) async {
    final generation = ++_generation;
    month = DateTime(selected.year, selected.month);
    loading = true;
    error = null;
    transactions = [];
    _emit();
    try {
      final result = await repository.transactions(month);
      if (generation == _generation) transactions = result;
    } catch (_) {
      if (generation == _generation) {
        error = 'Transactions could not be loaded. Please retry.';
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> save(MoneyTransaction transaction) async {
    await repository.save(transaction);
    await loadMonth(transaction.date);
  }

  Future<void> recoverReceipt() async {
    try {
      recoveredReceipt = await receipts.recover();
    } catch (_) {
      receiptRecoveryError = 'An interrupted image selection could not be recovered. Please select the screenshot again.';
    }
    _emit();
  }

  void clearRecoveredReceipt() {
    recoveredReceipt = null;
    receiptRecoveryError = null;
    _emit();
  }

  Future<void> loadDebts() async {
    final generation = ++_debtGeneration;
    debtsLoading = true;
    debtError = null;
    _emit();
    try {
      final result = await repository.debts();
      final names = await repository.people();
      if (generation == _debtGeneration) {
        debts = result;
        people = names;
      }
    } catch (_) {
      if (generation == _debtGeneration) {
        debtError = 'Debt records could not be loaded. Please retry.';
      }
    } finally {
      if (generation == _debtGeneration) {
        debtsLoading = false;
        _emit();
      }
    }
  }

  DebtRecord? debt(int id) => debts.where((debt) => debt.id == id).firstOrNull;
  List<DebtRecord> shares(int transactionId) =>
      debts.where((debt) => debt.transactionId == transactionId).toList();
  int outstanding(DebtDirection direction) => debts
      .where((debt) => debt.direction == direction)
      .fold(0, (sum, debt) => sum + debt.remainingPaise);
  Future<void> saveDebt(DebtDraft draft) async {
    await repository.saveDebt(draft);
    await loadDebts();
  }

  Future<void> saveSharedExpense(
    MoneyTransaction transaction,
    DebtDraft draft,
  ) async {
    await repository.saveSharedExpense(transaction, draft);
    await loadMonth(transaction.date);
    await loadDebts();
  }

  Future<void> deleteDebt(int id) async {
    await repository.deleteDebt(id);
    await loadDebts();
  }

  Future<void> addRepayment(
    int id,
    int amount,
    DateTime date,
    String note,
  ) async {
    await repository.addRepayment(id, amount, date, note);
    await loadDebts();
  }

  Future<void> deleteRepayment(int id) async {
    await repository.deleteRepayment(id);
    await loadDebts();
  }

  Future<void> delete(int id) async {
    await repository.delete(id);
    await loadMonth(month);
  }

  Future<void> setTheme(ThemeMode mode) async {
    await repository.saveTheme(mode.name);
    themeMode = mode;
    _emit();
  }

  MoneyCategory category(int id) =>
      categories.firstWhere((category) => category.id == id);
  MonthSummary get summary => MonthSummary(transactions);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
