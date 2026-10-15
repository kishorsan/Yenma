import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/main-preview.dart' as preview;

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late SqliteMoneyRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma-preview-test-');
    repository = SqliteMoneyRepository(
      factory: databaseFactoryFfi,
      path: '${directory.path}${Platform.pathSeparator}preview.db',
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'preview seed fills every module and two months of transactions',
    () async {
      final today = DateTime(2026, 10, 3);

      await preview.seedPreviewData(repository, today: today);

      final august = await repository.transactions(DateTime(2026, 8));
      final september = await repository.transactions(DateTime(2026, 9));
      final october = await repository.transactions(DateTime(2026, 10));
      final transactions = [...august, ...september, ...october];
      expect(transactions, hasLength(32));
      expect(
        transactions.every((transaction) => transaction.source == 'SMS'),
        isTrue,
      );
      expect(
        transactions.map((transaction) => calendarDate(transaction.date)),
        containsAll([today, DateTime(2026, 8, 3)]),
      );
      expect(
        transactions.map((transaction) => transaction.title),
        containsAll([
          'Lunch at Meghana Foods',
          'Chai and evening snacks',
          'Zudio clothes',
          'Amazon electronics',
        ]),
      );

      final banks = await repository.referenceData.banks();
      expect(banks, hasLength(2));
      expect(
        banks.map((bank) => bank.name),
        containsAll(['HDFC Bank', 'ICICI Credit Card']),
      );

      expect(await repository.plansForMonth(today), hasLength(4));
      expect(await repository.plansForMonth(DateTime(2026, 9)), hasLength(1));
      expect(await repository.subscriptions(), hasLength(5));

      final emis = await repository.emis();
      expect(emis, hasLength(2));
      expect(await repository.emiInstallments(emis.first.id!), isNotEmpty);

      final loans = await repository.loans();
      expect(loans, hasLength(4));
      expect(loans.where((loan) => loan.isComplete), hasLength(1));
      expect(await repository.loanPayments(loans.first.id!), isNotEmpty);
      final reportLoan = loans.singleWhere(
        (loan) => loan.name == 'Personal loan · Report example',
      );
      final reportSchedule = await repository.loanPayments(reportLoan.id!);
      expect(reportSchedule, hasLength(48));
      expect(
        reportSchedule.fold<int>(0, (sum, row) => sum + row.principalPaise),
        43000000,
      );
      expect(
        reportSchedule.fold<int>(0, (sum, row) => sum + row.interestPaise),
        11686800,
      );
      expect(reportSchedule.first.totalPaise, 1365700);
      expect(reportSchedule.last.totalPaise, 1134100);

      final groups = await repository.splitGroups();
      expect(groups, hasLength(2));
      expect(
        await Future.wait(
          groups.map((group) => repository.splitEntries(group.id)),
        ),
        everyElement(isNotEmpty),
      );

      final debts = await repository.debts();
      expect(debts, hasLength(7));
      expect(
        debts.where((debt) => debt.direction == DebtDirection.owedToMe),
        hasLength(5),
      );
      expect(
        debts.where((debt) => debt.direction == DebtDirection.iOwe),
        hasLength(2),
      );
      final concertDebt = debts.singleWhere(
        (debt) => debt.title == 'Concert tickets',
      );
      expect(concertDebt.repaidPaise, 75000);
    },
  );

  test(
    'preview EMI schedule includes the processing fee exactly once',
    () async {
      final today = DateTime(2026, 10, 3);

      await preview.seedPreviewData(repository, today: today);

      final laptopEmi = (await repository.emis()).singleWhere(
        (emi) => emi.name == 'Laptop EMI',
      );
      final schedule = await repository.emiInstallments(laptopEmi.id!);

      expect(schedule, hasLength(12));
      expect(
        schedule.fold<int>(
          0,
          (total, installment) => total + installment.principalPaise,
        ),
        laptopEmi.principalPaise,
      );
      expect(schedule.where((installment) => installment.isPaid), hasLength(4));
      expect(
        schedule.where((installment) => !installment.isPaid),
        hasLength(8),
      );
      expect(laptopEmi.processingFeePaise, 29900);
      expect(laptopEmi.totalRepaymentPaise(schedule), 9029900);
    },
  );

  test('preview seed is idempotent', () async {
    final today = DateTime(2026, 10, 3);

    await preview.seedPreviewData(repository, today: today);
    await preview.seedPreviewData(repository, today: today);

    final august = await repository.transactions(DateTime(2026, 8));
    final september = await repository.transactions(DateTime(2026, 9));
    final october = await repository.transactions(DateTime(2026, 10));
    expect([...august, ...september, ...october], hasLength(32));
    expect(await repository.referenceData.banks(), hasLength(2));
    expect(await repository.plansForMonth(today), hasLength(4));
    expect(await repository.subscriptions(), hasLength(5));
    expect(await repository.emis(), hasLength(2));
    expect(await repository.loans(), hasLength(4));
    expect(await repository.splitGroups(), hasLength(2));
    expect(await repository.debts(), hasLength(7));
  });
}
