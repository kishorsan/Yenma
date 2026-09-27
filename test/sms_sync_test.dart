import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/data/sms_sync.dart';

void main() {
  test('SMS imports retain the message timestamp', () {
    final timestamp = DateTime(2026, 9, 10, 21, 37);
    final transaction = SmsParser.parse(
      BankSms(
        address: 'HDFC',
        body: 'INR 125.50 debited at Corner Cafe',
        timestamp: timestamp,
      ),
    );

    expect(transaction, isNotNull);
    expect(transaction!.date, timestamp);
  });
}
