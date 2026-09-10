import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/features/welcome_screen.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets(
    'launch quote is stable, skippable, and absent during navigation',
    (tester) async {
      final repository = MemoryRepository();
      await tester.pumpWidget(YenmaApp(repository: repository));
      await tester.pumpAndSettle();
      final quote = tester
          .widget<Text>(find.byKey(const ValueKey('welcome-quote')))
          .data!;
      expect(landingQuotes, contains(quote));
      await tester.pumpWidget(YenmaApp(repository: repository));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('welcome-quote'))).data,
        quote,
      );
      await tester.tap(find.text('Open my money'));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsOneWidget);
      expect(find.byKey(const ValueKey('welcome-quote')), findsNothing);
      await tester.tap(find.text('Debts'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-quote')), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final heading = tester.widget<Text>(find.text('Make yourself at home.'));
      expect(heading.style!.fontSize, 28);
      expect(find.byKey(const ValueKey('welcome-quote')), findsNothing);
    },
  );

  testWidgets('welcome automatically yields to money after two seconds', (
    tester,
  ) async {
    await tester.pumpWidget(YenmaApp(repository: MemoryRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Open my money'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Open my money'), findsNothing);
    expect(find.text('Your money, a little clearer.'), findsOneWidget);
    final header = tester.widget<Text>(
      find.text('Your money, a little clearer.'),
    );
    expect(header.style!.fontSize, 16);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Open my money'), findsNothing);
  });

  testWidgets('screen-reader users can finish reading before continuing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: WelcomeGate(child: const Text('Money screen')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Open my money'), findsOneWidget);
    await tester.tap(find.text('Open my money'));
    await tester.pump();
    expect(find.text('Money screen'), findsOneWidget);
  });
}
