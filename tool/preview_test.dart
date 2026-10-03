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

class TwoWeekPreviewRepository extends MemoryRepository {
  @override
  Future<List<MoneyTransaction>> transactions(DateTime month) async =>
      entries.toList()..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date == 0 ? b.id!.compareTo(a.id!) : date;
      });
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('$theme home preview with two weeks of bank transactions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      final repository = TwoWeekPreviewRepository()..theme = theme;
      final today = DateTime.now();
      final samples = [
        ('Fresh groceries', 245050, TransactionKind.expense, 2, 0),
        ('Metro and cab', 86000, TransactionKind.expense, 3, 2),
        ('Electricity bill', 184500, TransactionKind.expense, 7, 4),
        ('Streaming renewal', 49900, TransactionKind.expense, 8, 6),
        ('Monthly salary', 6500000, TransactionKind.income, 10, 8),
        ('Dinner with friends', 148000, TransactionKind.expense, 1, 10),
        ('Weekend shopping', 229900, TransactionKind.expense, 4, 12),
        ('Pharmacy', 78000, TransactionKind.expense, 5, 14),
      ];
      for (var index = 0; index < samples.length; index++) {
        final sample = samples[index];
        await repository.save(
          MoneyTransaction(
            title: sample.$1,
            amountPaise: sample.$2,
            kind: sample.$3,
            categoryId: sample.$4,
            date: DateTime(today.year, today.month, today.day - sample.$5, 12),
            source: 'SMS',
            bankName: 'HDFC Bank',
            externalId: 'preview-hdfc-$index',
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
        matchesGoldenFile('../docs/previews/home-$theme.png'),
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
      await tester.ensureVisible(find.text('Debt'));
      await tester.tap(find.text('Debt'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(YenmaApp),
        matchesGoldenFile('../docs/previews/debts-$theme.png'),
      );
    });
  }
}
