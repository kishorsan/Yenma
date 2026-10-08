import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/data/sms_sync.dart';
import 'package:yenma/domain/money.dart';

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

  test('HDFC card purchase is separated from the bank account', () {
    final transaction = SmsParser.parse(
      BankSms(
        address: 'HDFCCB',
        body: 'Spent Rs.219.41 On HDFC Bank Card XX4321 At ZOMATO LIMITED On 2026-10-08:23:07:12. Not You?',
        timestamp: DateTime(2026, 10, 9),
      ),
    )!;

    expect(transaction.bankName, 'HDFC Credit Card');
    expect(transaction.instrumentType, FinancialInstrumentType.creditCard);
    expect(transaction.instrumentLast4, '4321');
    expect(transaction.importRole, ImportedTransactionRole.cardPurchase);
    expect(transaction.kind, TransactionKind.expense);
    expect(transaction.title, 'ZOMATO LIMITED');
    expect(transaction.amountPaise, 21941);
    expect(transaction.date, DateTime(2026, 10, 8, 23, 7, 12));
  });

  test('successful card autopay is an expense', () {
    final transaction = SmsParser.parse(
      BankSms(
        address: 'HDFCCB',
        body: '''AutoPay (E-mandate) Success!
For Google Play
Txn Amt:INR1950.00
Dt:07/10/2026
Via:HDFC Bank CC 4321
Mandate ID: 00000001''',
        timestamp: DateTime(2026, 10, 7, 18),
      ),
    )!;

    expect(transaction.title, 'Google Play');
    expect(transaction.bankName, 'HDFC Credit Card');
    expect(transaction.kind, TransactionKind.expense);
    expect(transaction.instrumentType, FinancialInstrumentType.creditCard);
    expect(transaction.instrumentLast4, '4321');
    expect(transaction.date, DateTime(2026, 10, 7, 12));
  });

  test('card bill payment is a transfer rather than income', () {
    final transaction = SmsParser.parse(
      BankSms(
        address: 'HDFCCB',
        body: 'DEAR HDFCBANK CARDMEMBER, PAYMENT OF Rs. 4856.00 RECEIVED TOWARDS YOUR CREDIT CARD ENDING WITH 4321 ON 26-9-2026.',
        timestamp: DateTime(2026, 9, 26, 18),
      ),
    )!;

    expect(transaction.title, 'Credit card payment');
    expect(transaction.bankName, 'HDFC Credit Card');
    expect(transaction.kind, TransactionKind.transfer);
    expect(transaction.categoryId, 12);
    expect(transaction.importRole, ImportedTransactionRole.cardPayment);
    expect(transaction.instrumentLast4, '4321');
  });

  test('HDFC account debit and credit retain account identity', () {
    final debit = SmsParser.parse(
      BankSms(
        address: 'HDFCBK',
        body: '''Sent Rs.5000.00
From HDFC Bank A/C *1234
To SANGEETHA K P
On 22/09/26
Ref 000000000056''',
        timestamp: DateTime(2026, 9, 22, 18),
      ),
    )!;
    final credit = SmsParser.parse(
      BankSms(
        address: 'HDFCBK',
        body: 'Credit Alert! Rs.20000.00 credited to HDFC Bank A/c XX1234 on 07-10-26 from VPA sample@ybl (UPI 00000000022)',
        timestamp: DateTime(2026, 10, 7, 18),
      ),
    )!;

    expect(debit.instrumentType, FinancialInstrumentType.bankAccount);
    expect(debit.instrumentLast4, '1234');
    expect(debit.importRole, ImportedTransactionRole.accountDebit);
    expect(debit.kind, TransactionKind.expense);
    expect(credit.instrumentType, FinancialInstrumentType.bankAccount);
    expect(credit.instrumentLast4, '1234');
    expect(credit.importRole, ImportedTransactionRole.accountCredit);
    expect(credit.kind, TransactionKind.income);
  });

  test('future card debit notification is not imported', () {
    final transaction = SmsParser.parse(
      BankSms(
        address: 'HDFCCB',
        body: 'INR.199.00 will be debited on 20/09/2026 from HDFC Bank Card 4321 for NETFLIX',
        timestamp: DateTime(2026, 9, 18),
      ),
    );

    expect(transaction, isNull);
  });

  test('generic instrument rules apply to other recognized banks', () {
    final iciciCard = SmsParser.parse(
      BankSms(
        address: 'ICICIB',
        body: 'INR 750.00 spent on ICICI Bank Credit Card XX9876 at BOOK STORE',
        timestamp: DateTime(2026, 10, 8),
      ),
    )!;
    final sbiAccount = SmsParser.parse(
      BankSms(
        address: 'SBIINB',
        body: 'Rs.1200 debited from SBI Account XX2468 to POWER COMPANY',
        timestamp: DateTime(2026, 10, 8),
      ),
    )!;

    expect(iciciCard.bankName, 'ICICI Credit Card');
    expect(iciciCard.instrumentType, FinancialInstrumentType.creditCard);
    expect(iciciCard.instrumentLast4, '9876');
    expect(sbiAccount.bankName, 'SBI');
    expect(sbiAccount.instrumentType, FinancialInstrumentType.bankAccount);
    expect(sbiAccount.instrumentLast4, '2468');
  });

  test('every recognized institution derives a credit card source', () {
    for (final entry in SmsParser.bankNames.entries) {
      final transaction = SmsParser.parse(
        BankSms(
          address: entry.key,
          body:
              'Rs.100 spent on ${entry.value} Credit Card XX1234 at TEST SHOP',
          timestamp: DateTime(2026, 10, 8),
        ),
      )!;
      final issuer = entry.value.replaceFirst(
        RegExp(r'\s+Bank$', caseSensitive: false),
        '',
      );

      expect(
        transaction.bankName,
        '$issuer Credit Card',
        reason: 'Card variant for ${entry.value}',
      );
      expect(transaction.instrumentType, FinancialInstrumentType.creditCard);
    }
  });
}
