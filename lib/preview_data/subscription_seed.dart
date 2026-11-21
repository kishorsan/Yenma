import '../data/money_repository.dart';
import '../models/commitments/subscription.dart';

/// Creates active/inactive and monthly/yearly subscription examples.
Future<void> seedSubscriptionPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  for (final subscription in [
    const SubscriptionRecord(
      name: 'Netflix',
      amountPaise: 64900,
      billingDay: 11,
      period: SubscriptionPeriod.monthly,
      notifyMe: true,
      link: 'https://www.netflix.com',
    ),
    const SubscriptionRecord(
      name: 'Spotify',
      amountPaise: 11900,
      billingDay: 18,
      period: SubscriptionPeriod.monthly,
      notifyMe: true,
    ),
    const SubscriptionRecord(
      name: 'Google One',
      amountPaise: 13000,
      billingDay: 24,
      period: SubscriptionPeriod.monthly,
    ),
    SubscriptionRecord(
      name: 'Amazon Prime',
      amountPaise: 149900,
      billingDay: 6,
      billingMonth: anchor.month,
      period: SubscriptionPeriod.yearly,
      notifyMe: true,
    ),
    SubscriptionRecord(
      name: 'Disney+ Hotstar',
      amountPaise: 89900,
      billingDay: 15,
      billingMonth: anchor.month,
      period: SubscriptionPeriod.yearly,
      isActive: false,
    ),
  ]) {
    await repository.saveSubscription(subscription);
  }
}
