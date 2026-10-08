import 'package:flutter/services.dart';

import '../domain/money.dart';

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

class SmsSyncResult {
  const SmsSyncResult(this.imported, this.scanned, this.timestamp);
  final int imported;
  final int scanned;
  final DateTime timestamp;
}

class SmsParser {
  static const bankNames = <String, String>{
    'HDFC': 'HDFC Bank',
    'CANB': 'Canara Bank',
    'JPTR': 'Jupiter',
    'ICICI': 'ICICI Bank',
    'SBI': 'SBI',
    'AXS': 'Axis Bank',
    'KOTAK': 'Kotak Mahindra Bank',
    'IDFC': 'IDFC FIRST Bank',
    'BOI': 'Bank of India',
    'PNB': 'Punjab National Bank',
    'CBOI': 'Central Bank of India',
    'UBI': 'Union Bank',
  };

  static MoneyTransaction? parse(BankSms sms) {
    final upper = '${sms.address} ${sms.body}'.toUpperCase();
    final codes = bankNames.keys.toList()
      ..sort((left, right) => right.length.compareTo(left.length));
    final code = codes.firstWhere(
      (key) => upper.contains(key),
      orElse: () => '',
    );
    if (code.isEmpty) return null;
    if (_isPendingNotice(upper)) return null;
    final amount = RegExp(
      r'(?:INR|RS\.?|₹)\.?\s*([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(sms.body)?.group(1)?.replaceAll(',', '');
    final paise = amount == null ? null : parsePaise(amount);
    if (paise == null) return null;
    final instrumentType = _instrumentType(upper);
    final sourceName = _sourceName(bankNames[code]!, instrumentType);
    final isCardPayment =
        instrumentType == FinancialInstrumentType.creditCard &&
        RegExp(
          r'\bPAYMENT\b[\s\S]{0,80}\bRECEIVED\b|\bRECEIVED\b[\s\S]{0,80}\b(?:TOWARDS|FOR)\b[\s\S]{0,40}\b(?:CREDIT\s+CARD|CARD)\b',
        ).hasMatch(upper);
    final isCredit = RegExp(r'\b(CREDIT|CREDITED|RECEIVED|DEPOSIT|SALARY)\b')
        .hasMatch(upper);
    final isDebit = RegExp(r'\b(DEBIT|DEBITED|SPENT|PURCHASE|PAID|SENT)\b')
        .hasMatch(upper);
    final isSuccessfulCardAutoPay =
        instrumentType == FinancialInstrumentType.creditCard &&
        RegExp(r'\bAUTO\s*PAY\b|\bE-?MANDATE\b').hasMatch(upper) &&
        RegExp(r'\bSUCCESS(?:FUL)?\b').hasMatch(upper);
    if (!isCardPayment && !isCredit && !isDebit && !isSuccessfulCardAutoPay) {
      return null;
    }
    final kind = isCardPayment
        ? TransactionKind.transfer
        : isCredit && !isDebit
        ? TransactionKind.income
        : TransactionKind.expense;
    final recipient = _recipient(sms.body);
    final key = recipient == null ? null : _key(recipient);
    return MoneyTransaction(
      title: isCardPayment
          ? 'Credit card payment'
          : recipient ??
                (instrumentType == FinancialInstrumentType.creditCard
                    ? 'Card transaction'
                    : 'Bank transaction'),
      amountPaise: paise,
      kind: kind,
      categoryId: isCardPayment ? 12 : 13,
      date: _transactionDate(sms.body) ?? sms.timestamp,
      source: 'SMS',
      bankName: sourceName,
      instrumentType: instrumentType,
      instrumentLast4: _instrumentLast4(sms.body, instrumentType),
      importRole: isCardPayment
          ? ImportedTransactionRole.cardPayment
          : kind == TransactionKind.income
          ? ImportedTransactionRole.accountCredit
          : instrumentType == FinancialInstrumentType.creditCard
          ? ImportedTransactionRole.cardPurchase
          : ImportedTransactionRole.accountDebit,
      externalId: _key(
        '${sms.address}|${sms.timestamp.millisecondsSinceEpoch}|${sms.body}',
      ),
      recipientKey: key,
    );
  }

  static String? _recipient(String body) {
    final match = RegExp(
      r'\b(?:to|at|for|from|merchant)\s*:?\s*([A-Za-z][A-Za-z0-9 .&@_-]{1,60}?)(?=\s+(?:on|dt|ref|via|id|not\s+you)\b|\s*\(|[\r\n]|$)',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isPendingNotice(String upper) => RegExp(
    r'\bWILL\s+BE\s+(?:DEBITED|CHARGED)\b|\bUPCOMING\s+(?:DEBIT|PAYMENT)\b',
  ).hasMatch(upper);

  static FinancialInstrumentType _instrumentType(String upper) =>
      RegExp(r'\b(?:CREDIT\s+CARD|CC|CARD)\b').hasMatch(upper)
      ? FinancialInstrumentType.creditCard
      : FinancialInstrumentType.bankAccount;

  static String _sourceName(
    String institution,
    FinancialInstrumentType instrumentType,
  ) {
    if (instrumentType != FinancialInstrumentType.creditCard) {
      return institution;
    }
    final issuer = institution.replaceFirst(
      RegExp(r'\s+Bank$', caseSensitive: false),
      '',
    );
    return '$issuer Credit Card';
  }

  static String? _instrumentLast4(String body, FinancialInstrumentType type) {
    final label = type == FinancialInstrumentType.creditCard
        ? r'\b(?:credit\s+card|card|cc)\b'
        : r'\b(?:a\s*\/\s*c|a\/c|acct|account)\b';
    final match = RegExp(
      '$label[\\s\\S]{0,35}?(?:[Xx* -]*)(\\d{4})\\b',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1);
  }

  static DateTime? _transactionDate(String body) {
    final full = RegExp(
      r'\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})(?::(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(body);
    if (full != null) {
      return _validDate(
        int.parse(full[1]!),
        int.parse(full[2]!),
        int.parse(full[3]!),
        int.tryParse(full[4] ?? '') ?? 12,
        int.tryParse(full[5] ?? '') ?? 0,
        int.tryParse(full[6] ?? '') ?? 0,
      );
    }
    final local = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b')
        .firstMatch(body);
    if (local == null) return null;
    var year = int.parse(local[3]!);
    if (year < 100) year += 2000;
    return _validDate(
      year,
      int.parse(local[2]!),
      int.parse(local[1]!),
      12,
      0,
      0,
    );
  }

  static DateTime? _validDate(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
  ) {
    final value = DateTime(year, month, day, hour, minute, second);
    return value.year == year &&
            value.month == month &&
            value.day == day &&
            value.hour == hour &&
            value.minute == minute &&
            value.second == second
        ? value
        : null;
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class SmsSyncService {
  static const _channel = MethodChannel('yenma/sms');
  Future<List<BankSms>> read({DateTime? from, DateTime? until}) async {
    final values =
        await _channel.invokeListMethod<dynamic>('readMessages', {
          if (from != null) 'from': from.millisecondsSinceEpoch,
          if (until != null) 'until': until.millisecondsSinceEpoch,
        }) ??
        const [];

    return values
        .map((value) {
          final row = Map<String, dynamic>.from(value as Map);
          return BankSms(
            address: row['address'] as String,
            body: row['body'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
          );
        })
        .where((sms) {
          final afterStart = from == null || !sms.timestamp.isBefore(from);
          final beforeEnd = until == null || sms.timestamp.isBefore(until);
          return afterStart && beforeEnd;
        })
        .toList();
  }

  Future<void> scheduleDaily() => _channel.invokeMethod('scheduleDailySync');
}
