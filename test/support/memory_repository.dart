import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/domain/monthly_plan.dart';
import 'package:yenma/domain/split.dart';

import 'dart:typed_data';

class MemoryRepository implements MoneyRepository {
  final _people = <String, String>{};
  @override
  Future<List<String>> people() async =>
      _people.values.toList()
        ..sort((a, b) => personNameKey(a).compareTo(personNameKey(b)));
  final List<MoneyTransaction> entries = [];
  final List<MoneyPlan> moneyPlans = [];
  final List<PlanType> savedPlanTypes = [];
  String theme = 'system';
  bool smsConsent = false;
  bool initialSmsSyncComplete = false;
  bool failSave = false;
  int _id = 0;
  int _debtId = 0;
  int _repaymentId = 0;
  int _splitGroupId = 0;
  int _splitEntryId = 0;
  int _splitMemberId = 0;
  final _debts = <int, DebtDraft>{};
  final _receipts = <int, Uint8List>{};
  final _transactionReceipts = <int, Uint8List>{};
  final _repayments = <Repayment>[];
  final _splitGroups = <SplitGroup>[];
  final _splitEntries = <SplitEntry>[];
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
        source: transaction.source,
        bankName: transaction.bankName,
        externalId: transaction.externalId,
        recipientKey: transaction.recipientKey,
      ),
    );
    if (transaction.recipientKey != null) {
      _recipientCategories[transaction.recipientKey!] = transaction.categoryId;
    }
  }

  @override
  Future<List<MoneyPlan>> plansForMonth(DateTime month) async => moneyPlans
      .where(
        (plan) =>
            plan.month.year == month.year && plan.month.month == month.month,
      )
      .toList();

  @override
  Future<List<PlanType>> planTypes() async => List.of(savedPlanTypes);

  @override
  Future<void> savePlan(MoneyPlan plan) async {
    if (failSave) throw StateError('Disk full');
    final name = plan.planName.trim();
    var type = savedPlanTypes
        .where((item) => item.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    type ??= PlanType(id: savedPlanTypes.length + 1, name: name);
    if (!savedPlanTypes.any((item) => item.id == type!.id)) {
      savedPlanTypes.add(type);
    }
    final saved = MoneyPlan(
      id: plan.id ?? ++_id,
      planTypeId: type.id,
      planName: type.name,
      month: plan.month,
      plannedPaise: plan.plannedPaise,
      remainingPaise: plan.remainingPaise,
      note: plan.note.trim(),
    );
    moneyPlans.removeWhere((item) => item.id == saved.id);
    moneyPlans.add(saved);
  }

  @override
  Future<void> bulkCategorize(
    List<MoneyTransaction> transactions,
    int categoryId,
  ) async {
    final ids = transactions.map((transaction) => transaction.id).toSet();
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (!ids.contains(entry.id)) continue;
      entries[index] = MoneyTransaction(
        id: entry.id,
        title: entry.title,
        amountPaise: entry.amountPaise,
        kind: entry.kind,
        categoryId: categoryId,
        date: entry.date,
        note: entry.note,
        source: entry.source,
        bankName: entry.bankName,
        externalId: entry.externalId,
        recipientKey: entry.recipientKey,
        hasReceipt: entry.hasReceipt,
      );
      if (entry.recipientKey != null) {
        _recipientCategories[entry.recipientKey!] = categoryId;
      }
    }
  }

  @override
  Future<int> importTransactions(List<MoneyTransaction> transactions) async {
    var count = 0;
    for (final transaction in transactions) {
      if (transaction.externalId != null &&
          entries.any((item) => item.externalId == transaction.externalId)) {
        continue;
      }
      await save(transaction);
      count++;
    }
    return count;
  }

  final Map<String, int> _recipientCategories = {};
  final Set<String> _syncedDates = {};
  DateTime? _lastSmsSync;
  @override
  Future<int?> categoryForRecipient(String recipientKey) async =>
      _recipientCategories[recipientKey];
  @override
  Future<void> saveRecipientCategory(
    String recipientKey,
    int categoryId,
  ) async => _recipientCategories[recipientKey] = categoryId;
  @override
  Future<void> saveTransactionReceipt(
    int transactionId,
    Uint8List bytes,
  ) async {
    _transactionReceipts[transactionId] = bytes;
    final index = entries.indexWhere((entry) => entry.id == transactionId);
    if (index >= 0) {
      final entry = entries[index];
      entries[index] = MoneyTransaction(
        id: entry.id,
        title: entry.title,
        amountPaise: entry.amountPaise,
        kind: entry.kind,
        categoryId: entry.categoryId,
        date: entry.date,
        note: entry.note,
        source: entry.source,
        bankName: entry.bankName,
        externalId: entry.externalId,
        recipientKey: entry.recipientKey,
        hasReceipt: true,
      );
    }
  }

  @override
  Future<Uint8List?> transactionReceipt(int transactionId) async =>
      _transactionReceipts[transactionId];
  @override
  Future<void> deleteTransactionReceipt(int transactionId) async =>
      _transactionReceipts.remove(transactionId);
  @override
  Future<bool> wasSyncedOn(DateTime date) async =>
      _syncedDates.contains(dateKey(date));
  @override
  Future<void> markSynced(DateTime date) async =>
      _syncedDates.add(dateKey(date));
  @override
  Future<DateTime?> lastSmsSyncAt() async => _lastSmsSync;
  @override
  Future<void> recordSmsSync({
    required DateTime completedAt,
    required int imported,
    required bool automatic,
  }) async => _lastSmsSync = completedAt;

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
  Future<bool> loadSmsConsent() async => smsConsent;
  @override
  Future<void> saveSmsConsent(bool granted) async => smsConsent = granted;
  @override
  Future<bool> loadInitialSmsSyncComplete() async => initialSmsSyncComplete;
  @override
  Future<void> saveInitialSmsSyncComplete() async =>
      initialSmsSyncComplete = true;

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
    _people.putIfAbsent(
      personNameKey(draft.person),
      () => normalizePersonName(draft.person),
    );
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
  Future<int> saveSharedExpenses(
    MoneyTransaction transaction,
    List<DebtDraft> drafts,
  ) async {
    await save(transaction);
    final id = entries.last.id!;
    for (final draft in drafts) {
      await saveDebt(draft.linkedTo(id));
    }
    return id;
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

  @override
  Future<List<SplitGroup>> splitGroups() async {
    final groups = _splitGroups.map((group) {
      final recent = _splitEntries
          .where((entry) => entry.groupId == group.id)
          .map((entry) => entry.date)
          .fold<DateTime?>(
            null,
            (latest, date) =>
                latest == null || date.isAfter(latest) ? date : latest,
          );
      return SplitGroup(
        id: group.id,
        name: group.name,
        note: group.note,
        members: group.members,
        createdAt: group.createdAt,
        lastActivity: recent,
      );
    }).toList();
    groups.sort(
      (a, b) => (b.lastActivity ?? b.createdAt).compareTo(
        a.lastActivity ?? a.createdAt,
      ),
    );
    return groups;
  }

  @override
  Future<int> createSplitGroup({
    required String name,
    required String note,
    required List<String> memberNames,
  }) async {
    if (failSave) throw StateError('Disk full');
    final membersByKey = <String, String>{};
    for (final value in memberNames) {
      final member = normalizePersonName(value);
      if (member.isNotEmpty) {
        membersByKey.putIfAbsent(personNameKey(member), () => member);
      }
    }
    final cleanMembers = membersByKey.values.toList();
    if (name.trim().isEmpty || cleanMembers.isEmpty) {
      throw const SplitValidationException(
        'Enter a group name and at least one member.',
      );
    }
    final id = ++_splitGroupId;
    final members = cleanMembers
        .map((member) => SplitMember(id: ++_splitMemberId, name: member))
        .toList();
    _splitGroups.add(
      SplitGroup(
        id: id,
        name: name.trim(),
        note: note.trim(),
        members: members,
        createdAt: DateTime.now(),
      ),
    );
    for (final member in members) {
      _people[personNameKey(member.name)] = member.name;
    }
    return id;
  }

  @override
  Future<List<SplitEntry>> splitEntries(int groupId) async =>
      _splitEntries.where((entry) => entry.groupId == groupId).toList()
        ..sort((a, b) {
          final date = b.date.compareTo(a.date);
          return date == 0 ? b.id.compareTo(a.id) : date;
        });

  @override
  Future<int> saveSplitEntry(SplitEntryDraft draft) async {
    if (failSave) throw StateError('Disk full');
    final group = _splitGroups.where((item) => item.id == draft.groupId).first;
    final sum = draft.shares.fold<int>(
      0,
      (value, share) => value + share.amountPaise,
    );
    if (draft.title.trim().isEmpty || sum != draft.amountPaise) {
      throw const SplitValidationException(
        'Shares must be positive and add up to the total.',
      );
    }
    final payer = draft.payerAssociateId == null
        ? null
        : group.members
              .where((member) => member.id == draft.payerAssociateId)
              .first;
    final savedShares = <SplitEntryShare>[];
    for (final share in draft.shares) {
      int? debtId;
      if (payer == null && !share.isMe) {
        debtId = ++_debtId;
        _debts[debtId] = DebtDraft(
          person: share.name,
          title: draft.title,
          amountPaise: share.amountPaise,
          direction: DebtDirection.owedToMe,
          date: draft.date,
          note: draft.note,
        );
      } else if (payer != null && share.isMe) {
        debtId = ++_debtId;
        _debts[debtId] = DebtDraft(
          person: payer.name,
          title: draft.title,
          amountPaise: share.amountPaise,
          direction: DebtDirection.iOwe,
          date: draft.date,
          note: draft.note,
        );
      }
      savedShares.add(
        SplitEntryShare(
          associateId: share.associateId,
          name: share.name,
          isMe: share.isMe,
          amountPaise: share.amountPaise,
          debtId: debtId,
          remainingPaise: debtId == null ? null : share.amountPaise,
        ),
      );
    }
    final id = ++_splitEntryId;
    _splitEntries.add(
      SplitEntry(
        id: id,
        groupId: draft.groupId,
        title: draft.title.trim(),
        amountPaise: draft.amountPaise,
        date: draft.date,
        note: draft.note.trim(),
        payerName: payer?.name ?? 'Me',
        recordedForSomeoneElse: payer != null,
        shares: savedShares,
      ),
    );
    return id;
  }
}
