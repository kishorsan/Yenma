// Local documentation previews, intentionally outside the regular test suite.
// flutter test tool/preview_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/domain/debt.dart';

import '../test/support/memory_repository.dart';

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('$theme overview preview with synthetic transactions', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final font = File('C:/Windows/Fonts/segoeui.ttf');
        if (await font.exists()) {
          final loader = FontLoader('Roboto')
            ..addFont(font.readAsBytes().then(ByteData.sublistView));
          await loader.load();
        }
      });
      final repository = MemoryRepository()..theme = theme;
      for (final sample in [
        ('Monthly salary', 6500000, TransactionKind.income, 10),
        ('Weekly groceries', 245050, TransactionKind.expense, 2),
        ('Lunch with friends', 68000, TransactionKind.expense, 1),
        ('Metro top-up', 50000, TransactionKind.expense, 3),
      ]) {
        await repository.save(
          MoneyTransaction(
            title: sample.$1,
            amountPaise: sample.$2,
            kind: sample.$3,
            categoryId: sample.$4,
            date: DateTime.now(),
          ),
        );
      }
      await tester.pumpWidget(
        RepaintBoundary(child: YenmaApp(repository: repository)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(YenmaApp),
        matchesGoldenFile('../docs/previews/welcome-$theme.png'),
      );
      await tester.tap(find.text('Open my money'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(YenmaApp),
        matchesGoldenFile('../docs/previews/overview-$theme.png'),
      );
      await repository.saveDebt(
        DebtDraft(
          person: 'Arun',
          title: 'Dinner after work',
          amountPaise: 25000,
          direction: DebtDirection.owedToMe,
          date: DateTime.now(),
          note: 'Your half of the meal. Pay whenever you can.',
        ),
      );
      await repository.saveDebt(
        DebtDraft(
          person: 'Arun',
          title: 'Movie tickets',
          amountPaise: 35000,
          direction: DebtDirection.owedToMe,
          date: DateTime.now(),
        ),
      );
      await repository.addRepayment(
        (await repository.debts()).last.id,
        10000,
        DateTime.now(),
        'Received via UPI',
      );
      await repository.saveDebt(
        DebtDraft(
          person: 'Meera',
          title: 'Cab home',
          amountPaise: 15000,
          direction: DebtDirection.iOwe,
          date: DateTime.now(),
        ),
      );
      // Reopen the app against the same in-memory fixture to load the demo debts.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        RepaintBoundary(
          child: YenmaApp(showWelcome: false, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Debts'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(YenmaApp),
        matchesGoldenFile('../docs/previews/debts-$theme.png'),
      );
    });
  }
}
