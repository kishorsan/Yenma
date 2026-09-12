import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:typed_data';

import '../data/money_repository.dart';
import '../domain/money.dart';
import '../domain/debt.dart';
import '../data/receipt_source.dart';
import '../data/sms_sync.dart';

class MoneyController extends ChangeNotifier {
  MoneyController(this.repository, {ReceiptSource? receipts, SmsSyncService? sms})
    : receipts = receipts ?? ImageReceiptSource(), sms = sms ?? SmsSyncService();
  final MoneyRepository repository;
  final ReceiptSource receipts;
  final SmsSyncService sms;
  bool syncing = false;
  String? syncMessage;
  bool smsConsentGranted = false;
  bool initialSmsSyncComplete = false;
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
      smsConsentGranted = await repository.loadSmsConsent();
      initialSmsSyncComplete = await repository.loadInitialSmsSyncComplete();
      final theme = await repository.loadTheme();
      themeMode =
          ThemeMode.values.where((mode) => mode.name == theme).firstOrNull ??
          ThemeMode.system;
      await loadMonth(month);
      await loadDebts();
      try {
        await sms.scheduleDaily();
      } on PlatformException {
        // Desktop/widget-test hosts do not expose the Android SMS channel.
      } catch (_) {}
      final now = DateTime.now();
      final lastSync = await repository.lastSmsSyncAt();
      final syncedToday = lastSync != null && dateKey(lastSync) == dateKey(now);
      if (smsConsentGranted && now.hour >= 22 && !syncedToday) {
        await syncMessages(automatic: true);
      }
    } catch (_) {
      error = 'Your local data could not be opened. Please try again.';
    } finally {
      initializing = false;
      _emit();
    }
  }

  Future<void> grantSmsConsent() async {
    smsConsentGranted = true;
    await repository.saveSmsConsent(true);
    _emit();
  }

  Future<void> syncMessages({bool automatic = false}) async {
    if (syncing) return;
    syncing = true;
    syncMessage = null;
    _emit();
    try {
      final now = DateTime.now();
      final lastSync = await repository.lastSmsSyncAt();
      final from = initialSmsSyncComplete
          ? (lastSync ?? DateTime(now.year, now.month, now.day))
          : DateTime(now.year, now.month - 3, now.day);
      final messages = await sms.read(from: from, until: now);
      final imports = <MoneyTransaction>[];
      for (final message in messages) {
        final parsed = SmsParser.parse(message);
        if (parsed == null) continue;
        final learned = parsed.recipientKey == null
            ? null
            : await repository.categoryForRecipient(parsed.recipientKey!);
        imports.add(learned == null ? parsed : MoneyTransaction(
          title: parsed.title, amountPaise: parsed.amountPaise, kind: parsed.kind,
          categoryId: learned, date: parsed.date, note: parsed.note,
          source: parsed.source, bankName: parsed.bankName,
          externalId: parsed.externalId, recipientKey: parsed.recipientKey,
        ));
      }
      final count = await repository.importTransactions(imports);
      if (!initialSmsSyncComplete) {
        await repository.saveInitialSmsSyncComplete();
        initialSmsSyncComplete = true;
      }
      await repository.recordSmsSync(completedAt: now, imported: count, automatic: automatic);
      await repository.markSynced(DateTime.now());
      await loadMonth(month);
      syncMessage = count == 0 ? 'Transactions are already up to date' : '$count transaction${count == 1 ? '' : 's'} synced';
    } on PlatformException catch (error) {
      syncMessage = error.code == 'permission_denied' ? 'SMS permission is needed to sync transactions' : 'Could not sync messages';
    } catch (_) {
      syncMessage = 'Could not sync messages';
    } finally {
      syncing = false;
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

  Future<void> save(MoneyTransaction transaction, {Uint8List? receipt}) async {
    await repository.save(transaction);
    if (receipt != null) {
      final id = transaction.id ?? (await repository.transactions(transaction.date))
          .where((item) => item.title.trim() == transaction.title.trim() &&
              item.amountPaise == transaction.amountPaise && item.date == transaction.date)
          .first.id!;
      await repository.saveTransactionReceipt(id, receipt);
    }
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

  Future<void> saveSharedExpenses(
    MoneyTransaction transaction,
    List<DebtDraft> drafts,
    {Uint8List? receipt}
  ) async {
    final id = await repository.saveSharedExpenses(transaction, drafts);
    if (receipt != null) await repository.saveTransactionReceipt(id, receipt);
    // The bill belongs to the parent transaction, not to an individual share.
    // The form calls this method before it can navigate away, so persist it here.
    // Attachment replacement/removal is handled by the transaction form state.
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

  Future<void> restore(MoneyTransaction transaction) async {
    await repository.save(MoneyTransaction(
      title: transaction.title,
      amountPaise: transaction.amountPaise,
      kind: transaction.kind,
      categoryId: transaction.categoryId,
      date: transaction.date,
      note: transaction.note,
      source: transaction.source,
      bankName: transaction.bankName,
      externalId: transaction.externalId,
      recipientKey: transaction.recipientKey,
    ));
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
