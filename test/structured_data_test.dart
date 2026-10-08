import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/commitments_data.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/data/reference_data.dart';
import 'package:yenma/data/splitting_data.dart';
import 'package:yenma/domain/monthly_plan.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteMoneyRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma_structured_');
    repository = SqliteMoneyRepository(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'money.db'),
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('fresh database creates every DBML table', () async {
    final rows = await repository.debtDatabase.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = rows.map((row) => row['name']).toSet();
    expect(
      tables,
      containsAll({
        'categories',
        'transactions',
        'banks',
        'transaction_receipt_chunks',
        'debts',
        'debt_receipt_chunks',
        'repayments',
        'associates',
        'associate_group',
        'associate_group_mapping',
        'split_allocation',
        'split_allocation_mapping',
        'split_allocation_share',
        'plan_type',
        'money_plans',
        'subscriptions',
        'loans',
        'loan_tracking',
        'settings',
        'sms_sync_log',
      }),
    );
  });

  test('v13 subscription rows gain a yearly billing month', () async {
    await repository.close();
    final databasePath = p.join(directory.path, 'money.db');
    await databaseFactoryFfi.deleteDatabase(databasePath);
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 13,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE subscriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subscription_name TEXT NOT NULL,
            amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
            subscription_date INTEGER NOT NULL CHECK(subscription_date BETWEEN 1 AND 28),
            type INTEGER NOT NULL CHECK(type IN (0,1)),
            is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
            notify_me INTEGER NOT NULL DEFAULT 0 CHECK(notify_me IN (0,1)),
            subscription_link TEXT
          )''');
          await db.insert('subscriptions', {
            'subscription_name': 'Legacy annual plan',
            'amount_paise': 120000,
            'subscription_date': 12,
            'type': SubscriptionPeriod.yearly.index,
          });
        },
      ),
    );
    await legacy.close();

    repository = SqliteMoneyRepository(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await repository.initialize();

    expect(await repository.debtDatabase.getVersion(), 16);
    final subscriptions = await repository.subscriptions();
    expect(subscriptions.single.billingMonth, 1);
  });

  test('group repositories enforce relationships and atomic totals', () async {
    final associateId = await repository.referenceData.saveAssociate(
      const AssociateRecord(name: 'Arun', phoneNumber: '+919999999999'),
    );
    final groupId = await repository.splitting.createGroup('Trip', [
      associateId,
    ]);
    final allocationId = await repository.splitting.saveAllocation(
      SplitAllocationRecord(
        associateGroupId: groupId,
        amountPaise: 25000,
        date: DateTime(2026, 10, 1),
        shares: [SplitShare(associateId: associateId, amountPaise: 25000)],
      ),
    );
    expect(allocationId, greaterThan(0));
    await expectLater(
      repository.splitting.saveAllocation(
        SplitAllocationRecord(
          amountPaise: 25000,
          date: DateTime(2026, 10, 1),
          shares: [SplitShare(associateId: associateId, amountPaise: 20000)],
        ),
      ),
      throwsArgumentError,
    );
    final outsiderId = await repository.referenceData.saveAssociate(
      const AssociateRecord(name: 'Meera'),
    );
    await expectLater(
      repository.splitting.saveAllocation(
        SplitAllocationRecord(
          associateGroupId: groupId,
          amountPaise: 100,
          date: DateTime(2026, 10, 1),
          shares: [SplitShare(associateId: outsiderId, amountPaise: 100)],
        ),
      ),
      throwsArgumentError,
    );

    await repository.savePlan(
      MoneyPlan(
        planName: 'Travel',
        month: DateTime(2026, 11),
        plannedPaise: 100000,
        remainingPaise: 75000,
      ),
    );
    final plans = await repository.planning.plansForMonth('2026-11');
    expect(plans, hasLength(1));
    expect(plans.single.remainingAmount, 75000);
  });

  test(
    'loan tracking updates the cached paid amount transactionally',
    () async {
      final loanId = await repository.commitments.saveLoan(
        LoanRecord(
          totalAmountPaise: 100000,
          startDate: DateTime(2026, 1, 1),
          type: LoanType.emiAmortizing,
          isEmi: true,
        ),
      );
      await repository.commitments.saveLoanTracking(
        LoanTrackingRecord(
          loanId: loanId,
          principalPaise: 25000,
          interestPaise: 1000,
          date: DateTime(2026, 2, 1),
          isPaid: true,
        ),
      );
      final rows = await repository.debtDatabase.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
      );
      expect(rows.single['amount_paid_paise'], 25000);
      expect(rows.single['status'], 'PENDING');
    },
  );

  test('subscriptions persist recurrence and enforce billing dates', () async {
    await repository.commitments.saveSubscription(
      const SubscriptionRecord(
        name: 'Music',
        amountPaise: 99900,
        billingDay: 12,
        billingMonth: 10,
        period: SubscriptionPeriod.yearly,
      ),
    );
    final saved = await repository.commitments.subscriptions(active: true);
    expect(saved, hasLength(1));
    expect(saved.single.billingMonth, 10);
    expect(saved.single.period, SubscriptionPeriod.yearly);
    await expectLater(
      repository.commitments.saveSubscription(
        const SubscriptionRecord(
          name: 'Invalid',
          amountPaise: 100,
          billingDay: 31,
          period: SubscriptionPeriod.monthly,
        ),
      ),
      throwsA(anything),
    );
  });
}
