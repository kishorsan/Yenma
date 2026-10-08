import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/app/theme.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/features/bulk_categorization_screen.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets(
    'bulk categorization shows last month through today and keeps latest first',
    (tester) async {
      tester.view.physicalSize = const Size(430, 940);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final lastMonth = DateTime(now.year, now.month - 1);
      final repository = MemoryRepository();
      repository.entries.addAll([
        _transaction(
          1,
          'Older groceries',
          now.subtract(const Duration(days: 2)),
        ),
        _transaction(2, 'Recent coffee', now),
        _transaction(
          3,
          'Last month fuel',
          DateTime(lastMonth.year, lastMonth.month),
        ),
        _transaction(
          4,
          'Too old',
          DateTime(
            currentMonth.year,
            currentMonth.month - 1,
          ).subtract(const Duration(days: 1)),
        ),
        _transaction(5, 'Future payment', now.add(const Duration(days: 1))),
      ]);
      final controller = MoneyController(repository);
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: yenmaTheme(Brightness.light),
          home: Scaffold(
            body: BulkCategorizationScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent coffee'), findsOneWidget);
      expect(find.text('Older groceries'), findsOneWidget);
      expect(find.text('Last month fuel'), findsOneWidget);
      expect(find.text('Too old'), findsNothing);
      expect(find.text('Future payment'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Recent coffee')).dy,
        lessThan(tester.getTopLeft(find.text('Older groceries')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Older groceries')).dy,
        lessThan(tester.getTopLeft(find.text('Last month fuel')).dy),
      );
      expect(find.byTooltip('Previous month'), findsNothing);
      expect(find.byTooltip('Next month'), findsNothing);
    },
  );

  testWidgets('selection opens a dismissible category sheet and applies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final repository = MemoryRepository();
    repository.entries.add(
      _transaction(1, 'Recent coffee', DateTime(now.year, now.month, 7)),
    );
    final controller = MoneyController(repository);
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: yenmaTheme(Brightness.light),
        home: Scaffold(body: BulkCategorizationScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recent coffee'));
    await tester.pumpAndSettle();
    expect(find.text('Categorize 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('categorize-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a category'), findsOneWidget);

    await tester.drag(find.text('Choose a category'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Choose a category'), findsNothing);
    expect(find.text('Categorize 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('categorize-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-1')));
    await tester.pumpAndSettle();

    expect(find.text('Categorize 1'), findsNothing);
    expect(repository.entries.single.categoryId, 1);
    expect(find.text('1 transaction categorized'), findsOneWidget);
  });
}

MoneyTransaction _transaction(int id, String title, DateTime date) =>
    MoneyTransaction(
      id: id,
      title: title,
      amountPaise: 12500,
      kind: TransactionKind.expense,
      categoryId: 13,
      date: date,
    );
