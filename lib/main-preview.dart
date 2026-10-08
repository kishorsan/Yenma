// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'app/yenma_app.dart';
import 'data/commitments_data.dart';
import 'data/money_repository.dart';
import 'data/reference_data.dart';
import 'data/sms_sync.dart';
import 'domain/debt.dart';
import 'domain/money.dart';
import 'domain/monthly_plan.dart';
import 'domain/split.dart';

const _previewDatabaseName = 'yenma-preview.db';
const _previewSeedKey = 'preview_seed_version';
const _previewSeedVersion = '2';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databasePath = path.join(
    await getDatabasesPath(),
    _previewDatabaseName,
  );
  const resetPreview = bool.fromEnvironment('RESET_PREVIEW');
  if (resetPreview) await deleteDatabase(databasePath);

  final repository = SqliteMoneyRepository(path: databasePath);
  await repository.initialize();
  await seedPreviewData(repository);

  runApp(
    YenmaApp(
      repository: repository,
      sms: PreviewSmsSyncService(),
      showWelcome: false,
    ),
  );
}

/// Adds deterministic sample content to the isolated preview database.
///
/// Dates are calculated from [today] so the fixtures always cover the latest
/// two calendar months. A version marker makes this idempotent and preserves
/// edits made while testing the preview app.
Future<void> seedPreviewData(
  SqliteMoneyRepository repository, {
  DateTime? today,
}) async {
  final support = repository.applicationSupport;
  if (await support.setting(_previewSeedKey) == _previewSeedVersion) return;

  final anchor = calendarDate(today ?? DateTime.now());
  await repository.referenceData.saveBank(
    const BankRecord(name: 'HDFC Bank', code: 'HDFC'),
  );
  await repository.referenceData.saveBank(
    const BankRecord(
      name: 'ICICI Credit Card',
      code: 'ICICI_CC',
      isCreditCard: true,
    ),
  );
  await _seedTransactions(repository, anchor);
  await _seedPlans(repository, anchor);
  await _seedSubscriptions(repository, anchor);
  await _seedEmis(repository, anchor);
  await _seedLoans(repository, anchor);
  await _seedSplits(repository, anchor);
  await _seedDebts(repository, anchor);
  await support.saveSetting(_previewSeedKey, _previewSeedVersion);
}

Future<void> _seedTransactions(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  const seeds = <_PreviewTransactionSeed>[
    _PreviewTransactionSeed('Lunch at Meghana Foods', 48500, 1, 0),
    _PreviewTransactionSeed('Chai and evening snacks', 14500, 1, 1),
    _PreviewTransactionSeed('Zudio clothes', 289900, 4, 3),
    _PreviewTransactionSeed('Uber ride', 37800, 3, 5),
    _PreviewTransactionSeed('Reliance Fresh', 176450, 2, 7),
    _PreviewTransactionSeed('Amazon electronics', 649900, 4, 9),
    _PreviewTransactionSeed('Netflix', 64900, 8, 11),
    _PreviewTransactionSeed('Office lunch', 32000, 1, 13),
    _PreviewTransactionSeed('Apollo Pharmacy', 87500, 5, 15),
    _PreviewTransactionSeed('Electricity bill', 214500, 7, 17),
    _PreviewTransactionSeed('Weekend movie', 74000, 6, 19),
    _PreviewTransactionSeed('Indian Oil', 250000, 3, 21),
    _PreviewTransactionSeed(
      'Monthly salary',
      7200000,
      10,
      23,
      kind: TransactionKind.income,
    ),
    _PreviewTransactionSeed('House rent', 1800000, 14, 24),
    _PreviewTransactionSeed('Swiggy dinner', 62000, 1, 26),
    _PreviewTransactionSeed('More supermarket', 223600, 2, 28),
    _PreviewTransactionSeed('Spotify', 11900, 8, 30),
    _PreviewTransactionSeed('Metro card recharge', 100000, 3, 32),
    _PreviewTransactionSeed('Myntra clothes', 199900, 4, 34),
    _PreviewTransactionSeed('Breakfast and coffee', 23500, 1, 36),
    _PreviewTransactionSeed('Mobile recharge', 74900, 7, 38),
    _PreviewTransactionSeed('Bookstore', 89900, 9, 40),
    _PreviewTransactionSeed('Dinner with friends', 184000, 1, 42),
    _PreviewTransactionSeed('Dental consultation', 120000, 5, 44),
    _PreviewTransactionSeed(
      'Monthly salary',
      7200000,
      10,
      47,
      kind: TransactionKind.income,
    ),
    _PreviewTransactionSeed('House rent', 1800000, 14, 48),
    _PreviewTransactionSeed('Laptop accessories', 229900, 4, 50),
    _PreviewTransactionSeed('BigBasket groceries', 268750, 2, 52),
    _PreviewTransactionSeed('Auto ride', 18000, 3, 54),
    _PreviewTransactionSeed('Lunch thali', 28000, 1, 56),
    _PreviewTransactionSeed('Internet bill', 117800, 7, 58),
    _PreviewTransactionSeed('Bakery snacks', 19500, 1, 61),
  ];
  await repository.importTransactions([
    for (var index = 0; index < seeds.length; index++)
      _previewTransaction(
        title: seeds[index].title,
        amountPaise: seeds[index].amountPaise,
        categoryId: seeds[index].categoryId,
        kind: seeds[index].kind,
        date: anchor.subtract(Duration(days: seeds[index].daysAgo)),
        sequence: index,
        bankName: index % 5 == 2 ? 'ICICI Credit Card' : 'HDFC Bank',
      ),
  ]);
}

Future<void> _seedPlans(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final currentMonth = DateTime(anchor.year, anchor.month);
  final previousMonth = _addMonths(currentMonth, -1);
  for (final plan in [
    MoneyPlan(
      planName: 'Daily expenses',
      month: currentMonth,
      plannedPaise: 3000000,
      remainingPaise: 1845000,
      note: 'Food, groceries and everyday travel',
    ),
    MoneyPlan(
      planName: 'Shopping',
      month: currentMonth,
      plannedPaise: 1200000,
      remainingPaise: 580100,
      note: 'Clothes and electronics',
    ),
    MoneyPlan(
      planName: 'Savings',
      month: currentMonth,
      plannedPaise: 1500000,
      remainingPaise: 1500000,
      note: 'Emergency fund contribution',
    ),
    MoneyPlan(
      planName: 'Entertainment',
      month: currentMonth,
      plannedPaise: 600000,
      remainingPaise: 331000,
    ),
    MoneyPlan(
      planName: 'Daily expenses',
      month: previousMonth,
      plannedPaise: 2800000,
      remainingPaise: 215000,
      note: 'Previous month plan',
    ),
  ]) {
    await repository.savePlan(plan);
  }
}

Future<void> _seedSubscriptions(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  for (final subscription in [
    const SubscriptionRecord(
      name: 'Netflix',
      amountPaise: 64900,
      billingDay: 11,
      period: SubscriptionPeriod.monthly,
      notifyMe: true,
      link: 'https://www.netflix.com',
    ),
    const SubscriptionRecord(
      name: 'Spotify',
      amountPaise: 11900,
      billingDay: 18,
      period: SubscriptionPeriod.monthly,
      notifyMe: true,
    ),
    const SubscriptionRecord(
      name: 'Google One',
      amountPaise: 13000,
      billingDay: 24,
      period: SubscriptionPeriod.monthly,
    ),
    SubscriptionRecord(
      name: 'Amazon Prime',
      amountPaise: 149900,
      billingDay: 6,
      billingMonth: anchor.month,
      period: SubscriptionPeriod.yearly,
      notifyMe: true,
    ),
    SubscriptionRecord(
      name: 'Disney+ Hotstar',
      amountPaise: 89900,
      billingDay: 15,
      billingMonth: anchor.month,
      period: SubscriptionPeriod.yearly,
      isActive: false,
    ),
  ]) {
    await repository.saveSubscription(subscription);
  }
}

Future<void> _seedEmis(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final laptopId = await repository.saveEmi(
    EmiRecord(
      name: 'Laptop EMI',
      principalPaise: 9000000,
      processingFeePaise: 99900,
      billingDay: 5,
      startDate: _addMonths(anchor, -4),
      endDate: _addMonths(anchor, 7),
      note: '12-month no-cost EMI',
    ),
  );
  for (var monthsAgo = 2; monthsAgo >= 0; monthsAgo--) {
    await repository.saveEmiInstallment(
      emiId: laptopId,
      principalPaise: 750000,
      interestPaise: 0,
      date: _monthDay(anchor, -monthsAgo, 5),
      isPaid: monthsAgo > 0 || anchor.day >= 5,
    );
  }

  final phoneId = await repository.saveEmi(
    EmiRecord(
      name: 'Phone EMI for Rahul',
      principalPaise: 4800000,
      processingFeePaise: 49900,
      billingDay: 20,
      startDate: _addMonths(anchor, -2),
      endDate: _addMonths(anchor, 9),
      note: 'Pass-through purchase; Rahul transfers the instalment',
      ownership: EmiOwnership.throughMe,
    ),
  );
  await repository.saveEmiInstallment(
    emiId: phoneId,
    principalPaise: 400000,
    interestPaise: 18000,
    date: _monthDay(anchor, -1, 20),
    isPaid: true,
  );
  await repository.saveEmiInstallment(
    emiId: phoneId,
    principalPaise: 400000,
    interestPaise: 16500,
    date: _monthDay(anchor, 0, anchor.day < 20 ? anchor.day : 20),
    isPaid: false,
  );
}

Future<void> _seedLoans(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final educationLoanId = await repository.saveLoan(
    LoanRecord(
      name: 'Education loan',
      totalAmountPaise: 45000000,
      startDate: _addMonths(anchor, -10),
      endDate: _addMonths(anchor, 26),
      note: 'Postgraduate course loan',
      type: LoanType.emiAmortizing,
    ),
  );
  for (final payment in [
    LoanTrackingRecord(
      loanId: educationLoanId,
      principalPaise: 3000000,
      interestPaise: 420000,
      gstPaise: 75600,
      date: anchor.subtract(const Duration(days: 45)),
      isPaid: true,
    ),
    LoanTrackingRecord(
      loanId: educationLoanId,
      principalPaise: 3200000,
      interestPaise: 395000,
      gstPaise: 71100,
      date: anchor.subtract(const Duration(days: 15)),
      isPaid: true,
    ),
  ]) {
    await repository.saveLoanPayment(payment);
  }

  final familyLoanId = await repository.saveLoan(
    LoanRecord(
      name: 'Family emergency loan',
      totalAmountPaise: 10000000,
      startDate: _addMonths(anchor, -5),
      endDate: _addMonths(anchor, 7),
      note: 'Interest-free family loan',
      type: LoanType.oneTime,
    ),
  );
  await repository.saveLoanPayment(
    LoanTrackingRecord(
      loanId: familyLoanId,
      principalPaise: 2500000,
      interestPaise: 0,
      date: anchor.subtract(const Duration(days: 28)),
      isPaid: true,
    ),
  );
}

Future<void> _seedSplits(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final tripId = await repository.createSplitGroup(
    name: 'Goa weekend',
    note: 'Travel, stay and food',
    memberNames: const ['Asha', 'Rahul'],
  );
  final trip = (await repository.splitGroups()).firstWhere(
    (group) => group.id == tripId,
  );
  final asha = trip.members.firstWhere((member) => member.name == 'Asha');
  final rahul = trip.members.firstWhere((member) => member.name == 'Rahul');
  await repository.saveSplitEntry(
    SplitEntryDraft(
      groupId: tripId,
      title: 'Beachside hotel',
      amountPaise: 900000,
      date: anchor.subtract(const Duration(days: 18)),
      payerAssociateId: null,
      note: 'Two nights',
      shares: [
        const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 300000),
        SplitEntryShare(
          associateId: asha.id,
          name: asha.name,
          isMe: false,
          amountPaise: 300000,
        ),
        SplitEntryShare(
          associateId: rahul.id,
          name: rahul.name,
          isMe: false,
          amountPaise: 300000,
        ),
      ],
    ),
  );
  await repository.saveSplitEntry(
    SplitEntryDraft(
      groupId: tripId,
      title: 'Airport cab',
      amountPaise: 180000,
      date: anchor.subtract(const Duration(days: 17)),
      payerAssociateId: asha.id,
      shares: [
        const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 60000),
        SplitEntryShare(
          associateId: asha.id,
          name: asha.name,
          isMe: false,
          amountPaise: 60000,
        ),
        SplitEntryShare(
          associateId: rahul.id,
          name: rahul.name,
          isMe: false,
          amountPaise: 60000,
        ),
      ],
    ),
  );

  final homeId = await repository.createSplitGroup(
    name: 'Flatmates',
    note: 'Shared home expenses',
    memberNames: const ['Meera', 'Vikram'],
  );
  final home = (await repository.splitGroups()).firstWhere(
    (group) => group.id == homeId,
  );
  await repository.saveSplitEntry(
    SplitEntryDraft(
      groupId: homeId,
      title: 'Monthly groceries',
      amountPaise: 240000,
      date: anchor.subtract(const Duration(days: 8)),
      payerAssociateId: null,
      shares: [
        const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 80000),
        for (final member in home.members)
          SplitEntryShare(
            associateId: member.id,
            name: member.name,
            isMe: false,
            amountPaise: 80000,
          ),
      ],
    ),
  );
}

Future<void> _seedDebts(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  await repository.saveDebt(
    DebtDraft(
      person: 'Karthik',
      title: 'Concert tickets',
      amountPaise: 250000,
      direction: DebtDirection.owedToMe,
      date: anchor.subtract(const Duration(days: 30)),
      note: 'Paid for both tickets',
    ),
  );
  await repository.saveDebt(
    DebtDraft(
      person: 'Priya',
      title: 'Dinner advance',
      amountPaise: 85000,
      direction: DebtDirection.iOwe,
      date: anchor.subtract(const Duration(days: 12)),
      note: 'Priya covered my share',
    ),
  );
}

DateTime _addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, date.day.clamp(1, lastDay));
}

DateTime _monthDay(DateTime anchor, int monthOffset, int day) {
  final target = DateTime(anchor.year, anchor.month + monthOffset, 1);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, day.clamp(1, lastDay));
}

class _PreviewTransactionSeed {
  const _PreviewTransactionSeed(
    this.title,
    this.amountPaise,
    this.categoryId,
    this.daysAgo, {
    this.kind = TransactionKind.expense,
  });

  final String title;
  final int amountPaise;
  final int categoryId;
  final int daysAgo;
  final TransactionKind kind;
}

MoneyTransaction _previewTransaction({
  required String title,
  required int amountPaise,
  required int categoryId,
  required DateTime date,
  required int sequence,
  required String bankName,
  TransactionKind kind = TransactionKind.expense,
}) => MoneyTransaction(
  title: title,
  amountPaise: amountPaise,
  kind: kind,
  categoryId: categoryId,
  date: DateTime(date.year, date.month, date.day, 12),
  source: 'SMS',
  bankName: bankName,
  instrumentType: bankName.toLowerCase().contains('credit card')
      ? FinancialInstrumentType.creditCard
      : FinancialInstrumentType.bankAccount,
  externalId: 'preview-v2-${dateKey(date)}-$sequence',
  recipientKey: transactionNameKey(title),
  note: 'Preview fixture',
);

/// Prevents preview runs from reading or scheduling access to real SMS data.
class PreviewSmsSyncService extends SmsSyncService {
  @override
  Future<List<BankSms>> read({DateTime? from, DateTime? until}) async =>
      const [];

  @override
  Future<void> scheduleDaily() async {}
}
