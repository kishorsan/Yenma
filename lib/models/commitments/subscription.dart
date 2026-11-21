/// Supported recurrence periods for subscription billing.
enum SubscriptionPeriod { monthly, yearly }

/// A recurring subscription and its next billing configuration.
class SubscriptionRecord {
  const SubscriptionRecord({
    this.id,
    required this.name,
    required this.amountPaise,
    required this.billingDay,
    this.billingMonth = 1,
    required this.period,
    this.isActive = true,
    this.notifyMe = false,
    this.link,
  });

  final int? id;
  final String name;
  final int amountPaise;
  final int billingDay;
  final int billingMonth;
  final SubscriptionPeriod period;
  final bool isActive;
  final bool notifyMe;
  final String? link;
}
