/// Raw SMS content received from the platform channel.
class BankSms {
  const BankSms({
    required this.address,
    required this.body,
    required this.timestamp,
  });

  final String address;
  final String body;
  final DateTime timestamp;
}
