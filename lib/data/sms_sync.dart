import 'package:flutter/services.dart';

import '../domain/money.dart';

class BankSms {
  const BankSms({required this.address, required this.body, required this.timestamp});
  final String address;
  final String body;
  final DateTime timestamp;
}

class SmsSyncResult {
  const SmsSyncResult(this.imported, this.scanned);
  final int imported;
  final int scanned;
}

class SmsParser {
  static const bankNames = <String, String>{
    'HDFC': 'HDFC Bank', 
    'CNRB': 'Canara Bank', 
    'JPTR': 'Jupiter',
    'ICICI': 'ICICI Bank', 
    'SBI': 'SBI', 
    'AXIS': 'Axis Bank',
    'KOTAK': 'Kotak Mahindra Bank', 
    'IDFC': 'IDFC FIRST Bank',
    'BOI': 'Bank of India', 
    'PNB': 'Punjab National Bank',
    'CBOI': 'Central Bank of India', 
    'UBI': 'Union Bank',
  };

  static MoneyTransaction? parse(BankSms sms) {
    final upper = '${sms.address} ${sms.body}'.toUpperCase();
    final code = bankNames.keys.firstWhere((key) => upper.contains(key), orElse: () => '');
    if (code.isEmpty) return null;
    final amount = RegExp(r'(?:INR|RS\.?|₹)\s*([0-9,]+(?:\.\d{1,2})?)', caseSensitive: false)
        .firstMatch(sms.body)?.group(1)?.replaceAll(',', '');
    final paise = amount == null ? null : parsePaise(amount);
    if (paise == null) return null;
    final isCredit = RegExp(r'\b(CREDIT|CREDITED|RECEIVED|DEPOSIT|SALARY)\b').hasMatch(upper);
    final isDebit = RegExp(r'\b(DEBIT|DEBITED|SPENT|PURCHASE|PAID|SENT)\b').hasMatch(upper);
    if (!isCredit && !isDebit) return null;
    final kind = isCredit && !isDebit ? TransactionKind.income : TransactionKind.expense;
    final recipient = _recipient(sms.body);
    final key = recipient == null ? null : _key(recipient);
    return MoneyTransaction(
      title: recipient ?? 'Bank transaction', amountPaise: paise, kind: kind,
      categoryId: 13, date: calendarDate(sms.timestamp), source: 'SMS',
      bankName: bankNames[code], externalId: _key('${sms.address}|${sms.timestamp.millisecondsSinceEpoch}|${sms.body}'),
      recipientKey: key,
    );
  }

  static String? _recipient(String body) {
    final match = RegExp(r'\b(?:to|at|towards|merchant)\s+([A-Za-z][A-Za-z0-9 .&_-]{1,60})', caseSensitive: false).firstMatch(body);
    return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _key(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class SmsSyncService {
  static const _channel = MethodChannel('yenma/sms');
  Future<List<BankSms>> read({DateTime? from, DateTime? until}) async {
    final values = await _channel.invokeListMethod<dynamic>('readMessages', {
      if (from != null) 'from': from.millisecondsSinceEpoch,
      if (until != null) 'until': until.millisecondsSinceEpoch,
    }) ?? const [];

    return values.map((value) {
      final row = Map<String, dynamic>.from(value as Map);
      return BankSms(address: row['address'] as String, body: row['body'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int));
    }).where((sms) {
      final afterStart = from == null || !sms.timestamp.isBefore(from);
      final beforeEnd = until == null || sms.timestamp.isBefore(until);
      return afterStart && beforeEnd;
    }).toList();
  }
  Future<void> scheduleDaily() => _channel.invokeMethod('scheduleDailySync');
}
