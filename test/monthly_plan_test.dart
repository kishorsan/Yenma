import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/domain/monthly_plan.dart';
import 'package:yenma/features/monthly_plan_screen.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('plan page suggests existing types and saves a simple plan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryRepository();
    final now = DateTime.now();
    await repository.savePlan(
      MoneyPlan(
        planName: 'Savings',
        month: DateTime(now.year, now.month - 1),
        plannedPaise: 500000,
        remainingPaise: 250000,
      ),
    );
    final controller = MoneyController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MonthlyPlanScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No plans for'), findsOneWidget);
    expect(find.text('Expected salary'), findsNothing);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    expect(find.text('Record Plan'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sav');
    await tester.pump();
    expect(find.text('Savings'), findsOneWidget);
    await tester.tap(find.text('Savings'));
    await tester.enterText(fields.at(1), '10000');
    await tester.enterText(fields.at(2), '8000');
    await tester.enterText(fields.at(3), 'Rainy day fund');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.moneyPlans, hasLength(2));
    final saved = repository.moneyPlans.last;
    expect(saved.planName, 'Savings');
    expect(saved.plannedPaise, 1000000);
    expect(saved.remainingPaise, 800000);
    expect(saved.planTypeId, 1);
    expect(find.text('₹8,000.00 remaining'), findsOneWidget);
    expect(find.text('Rainy day fund'), findsOneWidget);
  });
}
