import '../data/money_repository.dart';
import '../domain/monthly_plan.dart';
import 'preview_dates.dart';

/// Creates current and previous-month plans for the planning screen.
Future<void> seedPlanningPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final currentMonth = DateTime(anchor.year, anchor.month);
  final previousMonth = addPreviewMonths(currentMonth, -1);
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
