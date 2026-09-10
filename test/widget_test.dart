import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/yenma_app.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets(
    'manual transaction can be created, edited and deleted with confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = MemoryRepository();
      await tester.pumpWidget(YenmaApp(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('A fresh page for your money'), findsOneWidget);
      await tester.tap(find.text('Add transaction'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '125.50');
      await tester.enterText(find.byType(TextFormField).at(1), 'Lunch');
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save transaction'));
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(repository.entries.single.amountPaise, 12550);
      await tester.scrollUntilVisible(find.text('Lunch'), 250);
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit transaction'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'Dinner');
      await tester.ensureVisible(find.text('Save transaction'));
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(repository.entries.single.title, 'Dinner');
      await tester.ensureVisible(find.text('Dinner'));
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.entries, hasLength(1));
      await tester.tap(find.text('Delete transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repository.entries, isEmpty);
    },
  );

  testWidgets('validation and failed saves preserve entered details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryRepository()..failSave = true;
    await tester.pumpWidget(YenmaApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Give this transaction a title'), findsOneWidget);
    expect(repository.entries, isEmpty);
    await tester.enterText(find.byType(TextFormField).at(0), '20.25');
    await tester.enterText(find.byType(TextFormField).at(1), 'Coffee');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save.'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(repository.entries, isEmpty);
  });
}
