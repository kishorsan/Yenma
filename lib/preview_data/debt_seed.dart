import '../data/money_repository.dart';
import '../domain/debt.dart';

/// Creates both debt directions and a partially repaid personal debt.
Future<void> seedDebtPreviewData(
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

  final concertDebt = (await repository.debts()).firstWhere(
    (debt) => debt.person == 'Karthik' && debt.title == 'Concert tickets',
  );
  await repository.addRepayment(
    concertDebt.id,
    75000,
    anchor.subtract(const Duration(days: 5)),
    'Partial repayment via UPI',
  );
}
