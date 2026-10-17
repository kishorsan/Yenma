import '../domain/money.dart';
import '../models/sms_sync/bank_sms.dart';
import 'sms_transaction_references.dart';

/// Identifies a supported financial event and normalizes it as a transaction.
///
/// The stages are intentionally ordered: institution, finality, amount,
/// instrument, direction, and finally descriptive details. A failed required
/// stage stops the pipeline rather than letting later heuristics guess.
abstract final class SmsTransactionPipeline {
  /// Stable import identity. Delivery time keeps identical messages from two
  /// separate events distinct.
  static String sourceItemId(BankSms sms) => _key(
    '${sms.address}|${sms.timestamp.millisecondsSinceEpoch}|${sms.body}',
  );

  /// Returns `null` when [sms] cannot be identified as a final transaction.
  static MoneyTransaction? parse(BankSms sms) {
    final message = _NormalizedSms(sms);
    final institution = _identifyInstitution(message.text);
    if (institution == null ||
        _matches(message.text, SmsTransactionReferences.pendingNotice)) {
      return null;
    }

    final amountPaise = _extractAmount(sms.body);
    if (amountPaise == null) return null;

    final instrumentType = _identifyInstrument(message.text);
    final classification = _classify(message.text, instrumentType);
    if (classification == null) return null;

    final recipient = _extractRecipient(sms.body);
    final sourceName = _sourceName(institution.displayName, instrumentType);
    return MoneyTransaction(
      title: classification.isCardPayment
          ? 'Credit card payment'
          : recipient ??
                (instrumentType == FinancialInstrumentType.creditCard
                    ? 'Card transaction'
                    : 'Bank transaction'),
      amountPaise: amountPaise,
      kind: classification.kind,
      categoryId: classification.isCardPayment ? 12 : 13,
      date: _extractTransactionDate(sms.body) ?? sms.timestamp,
      source: 'SMS',
      bankName: sourceName,
      instrumentType: instrumentType,
      instrumentLast4: _extractInstrumentLast4(sms.body, instrumentType),
      importRole: classification.role,
      externalId: sourceItemId(sms),
      recipientKey: recipient == null ? null : _key(recipient),
    );
  }

  static SmsInstitutionReference? _identifyInstitution(String message) {
    final references = [...SmsTransactionReferences.institutions]
      ..sort(
        (left, right) =>
            right.senderCode.length.compareTo(left.senderCode.length),
      );
    for (final reference in references) {
      if (message.contains(reference.senderCode)) return reference;
    }
    return null;
  }

  static int? _extractAmount(String body) {
    final value = RegExp(
      SmsTransactionReferences.amount,
      caseSensitive: false,
    ).firstMatch(body)?.group(1)?.replaceAll(',', '');
    return value == null ? null : parsePaise(value);
  }

  static FinancialInstrumentType _identifyInstrument(String message) =>
      _matches(message, SmsTransactionReferences.creditCardInstrument)
      ? FinancialInstrumentType.creditCard
      : FinancialInstrumentType.bankAccount;

  static _TransactionClassification? _classify(
    String message,
    FinancialInstrumentType instrumentType,
  ) {
    final isCard = instrumentType == FinancialInstrumentType.creditCard;
    final isCardPayment =
        isCard && _matches(message, SmsTransactionReferences.cardPayment);
    final isCredit = _matches(
      message,
      SmsTransactionReferences.creditDirection,
    );
    final isDebit = _matches(message, SmsTransactionReferences.debitDirection);
    final isSuccessfulCardAutoPay =
        isCard &&
        _matches(message, SmsTransactionReferences.cardAutoPay) &&
        _matches(message, SmsTransactionReferences.successfulStatus);

    if (!isCardPayment && !isCredit && !isDebit && !isSuccessfulCardAutoPay) {
      return null;
    }
    if (isCardPayment) {
      return const _TransactionClassification(
        kind: TransactionKind.transfer,
        role: ImportedTransactionRole.cardPayment,
        isCardPayment: true,
      );
    }
    if (isCredit && !isDebit) {
      return const _TransactionClassification(
        kind: TransactionKind.income,
        role: ImportedTransactionRole.accountCredit,
      );
    }
    return _TransactionClassification(
      kind: TransactionKind.expense,
      role: isCard
          ? ImportedTransactionRole.cardPurchase
          : ImportedTransactionRole.accountDebit,
    );
  }

  static String? _extractRecipient(String body) {
    final match = RegExp(
      SmsTransactionReferences.recipient,
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

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

  static String? _extractInstrumentLast4(
    String body,
    FinancialInstrumentType type,
  ) {
    final label = type == FinancialInstrumentType.creditCard
        ? SmsTransactionReferences.creditCardLabel
        : SmsTransactionReferences.bankAccountLabel;
    return RegExp(
      '$label[\\s\\S]{0,35}?(?:[Xx* -]*)(\\d{4})\\b',
      caseSensitive: false,
    ).firstMatch(body)?.group(1);
  }

  static DateTime? _extractTransactionDate(String body) {
    final full = RegExp(SmsTransactionReferences.fullDate).firstMatch(body);
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
    final local = RegExp(SmsTransactionReferences.localDate).firstMatch(body);
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

  static bool _matches(String message, String reference) =>
      RegExp(reference).hasMatch(message);

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class _NormalizedSms {
  _NormalizedSms(BankSms sms)
    : text = '${sms.address} ${sms.body}'.toUpperCase();

  final String text;
}

class _TransactionClassification {
  const _TransactionClassification({
    required this.kind,
    required this.role,
    this.isCardPayment = false,
  });

  final TransactionKind kind;
  final ImportedTransactionRole role;
  final bool isCardPayment;
}
