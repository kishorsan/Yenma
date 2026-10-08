import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/data/commitments_data.dart';
import 'package:yenma/features/subscriptions/subscriptions_screen.dart';

import 'support/memory_repository.dart';

void main() {
  test('next billing date respects monthly and yearly cycles', () {
    const monthly = SubscriptionRecord(
      name: 'Music',
      amountPaise: 19900,
      billingDay: 8,
      period: SubscriptionPeriod.monthly,
    );
    const yearly = SubscriptionRecord(
      name: 'Storage',
      amountPaise: 199900,
      billingDay: 3,
      billingMonth: 10,
      period: SubscriptionPeriod.yearly,
    );

    expect(
      nextBillingDate(monthly, from: DateTime(2026, 10, 9)),
      DateTime(2026, 11, 8),
    );
    expect(
      nextBillingDate(yearly, from: DateTime(2026, 10, 3)),
      DateTime(2026, 10, 3),
    );
    expect(
      nextBillingDate(yearly, from: DateTime(2026, 10, 4)),
      DateTime(2027, 10, 3),
    );
  });

  testWidgets('records and opens a subscription', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository();
    final controller = MoneyController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SubscriptionsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No subscriptions yet'), findsOneWidget);
    await tester.tap(find.text('Record subscription'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Netflix');
    await tester.enterText(fields.at(1), '199');
    await tester.enterText(fields.at(2), 'netflix.com/account');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedSubscriptions, hasLength(1));
    expect(repository.savedSubscriptions.single.amountPaise, 19900);
    expect(
      repository.savedSubscriptions.single.link,
      'https://netflix.com/account',
    );
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('₹199.00'), findsOneWidget);

    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    expect(find.text('MONTHLY SUBSCRIPTION'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Visit'), findsOneWidget);
  });
}
