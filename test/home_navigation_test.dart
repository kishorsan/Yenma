import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/theme.dart';
import 'package:yenma/app/yenma_app.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('home exposes the confirmed navigation and feature priority', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      YenmaApp(repository: MemoryRepository(), showWelcome: false),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final destination in const [
      'Home',
      'Cards',
      'Categorize',
      'Settings',
    ]) {
      expect(find.text(destination), findsOneWidget);
    }
    for (final feature in const [
      'Plan',
      'Split',
      'Subscriptions',
      'EMI',
      'Loan',
      'Debt',
    ]) {
      expect(find.text(feature), findsOneWidget);
    }
    expect(find.byTooltip('Sync bank messages'), findsOneWidget);
    expect(find.byTooltip('Previous month'), findsNothing);
    expect(find.byTooltip('Next month'), findsNothing);

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('Card specific transactions'), findsOneWidget);
    expect(find.byTooltip('Sync bank messages'), findsNothing);
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);

    await tester.tap(find.text('Categorize'));
    await tester.pumpAndSettle();
    expect(
      find.text('There are no transactions in this month to categorize.'),
      findsOneWidget,
    );
  });

  test('grey themes expose semantic finance colors', () {
    final light = yenmaTheme(Brightness.light).extension<YenmaColors>();
    final dark = yenmaTheme(Brightness.dark).extension<YenmaColors>();

    expect(light, isNotNull);
    expect(dark, isNotNull);
    expect(light!.heroSurface, isNot(dark!.heroSurface));
    expect(light.income, isNot(light.expense));
  });
}
