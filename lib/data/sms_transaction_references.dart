/// A sender fragment and the institution name stored on imported transactions.
class SmsInstitutionReference {
  const SmsInstitutionReference(this.senderCode, this.displayName);

  final String senderCode;
  final String displayName;
}

/// Reference vocabulary used while identifying financial SMS messages.
///
/// Each expression is grouped by the decision it supports. Keeping these
/// references free of parsing flow makes additions reviewable without hiding
/// precedence or transaction construction among lists of keywords.
abstract final class SmsTransactionReferences {
  /// Sender codes establish that a message belongs to a supported institution.
  static const institutions = <SmsInstitutionReference>[
    SmsInstitutionReference('HDFC', 'HDFC Bank'),
    SmsInstitutionReference('CANB', 'Canara Bank'),
    SmsInstitutionReference('JPTR', 'Jupiter'),
    SmsInstitutionReference('ICICI', 'ICICI Bank'),
    SmsInstitutionReference('SBI', 'SBI'),
    SmsInstitutionReference('AXS', 'Axis Bank'),
    SmsInstitutionReference('KOTAK', 'Kotak Mahindra Bank'),
    SmsInstitutionReference('IDFC', 'IDFC FIRST Bank'),
    SmsInstitutionReference('BOI', 'Bank of India'),
    SmsInstitutionReference('PNB', 'Punjab National Bank'),
    SmsInstitutionReference('CBOI', 'Central Bank of India'),
    SmsInstitutionReference('UBI', 'Union Bank'),
  ];

  /// Locates an INR amount; a message without one cannot form a transaction.
  static const amount = r'(?:INR|RS\.?|₹)\.?\s*([0-9,]+(?:\.\d{1,2})?)';

  /// Prevents future or merely scheduled activity from being imported early.
  static const pendingNotice =
      r'\bWILL\s+BE\s+(?:DEBITED|CHARGED)\b|\bUPCOMING\s+(?:DEBIT|PAYMENT)\b';

  /// Distinguishes card activity from ordinary bank-account activity.
  static const creditCardInstrument = r'\b(?:CREDIT\s+CARD|CC|CARD)\b';

  /// Identifies money entering an account.
  static const creditDirection =
      r'\b(CREDIT|CREDITED|RECEIVED|DEPOSIT|SALARY)\b';

  /// Identifies money leaving an account or being spent on a card.
  static const debitDirection =
      r'\b(DEBIT|DEBITED|SPENT|PURCHASE|PAID|SENT)\b';

  /// Separates a credit-card bill payment from income credited to an account.
  static const cardPayment =
      r'\bPAYMENT\b[\s\S]{0,80}\bRECEIVED\b|\bRECEIVED\b[\s\S]{0,80}\b(?:TOWARDS|FOR)\b[\s\S]{0,40}\b(?:CREDIT\s+CARD|CARD)\b';

  /// Recognizes card mandates that completed without a debit-direction word.
  static const cardAutoPay = r'\bAUTO\s*PAY\b|\bE-?MANDATE\b';

  /// Requires a mandate notification to describe a completed transaction.
  static const successfulStatus = r'\bSUCCESS(?:FUL)?\b';

  /// Extracts a counterparty for a useful transaction title and category key.
  static const recipient =
      r'\b(?:to|at|for|from|merchant)\s*:?\s*([A-Za-z][A-Za-z0-9 .&@_-]{1,60}?)(?=\s+(?:on|dt|ref|via|id|not\s+you)\b|\s*\(|[\r\n]|$)';

  /// Labels that precede a bank-account suffix.
  static const bankAccountLabel = r'\b(?:a\s*\/\s*c|a\/c|acct|account)\b';

  /// Labels that precede a credit-card suffix.
  static const creditCardLabel = r'\b(?:credit\s+card|card|cc)\b';

  /// Reads full ISO-like dates, optionally including a time.
  static const fullDate =
      r'\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})(?::(\d{1,2}):(\d{2})(?::(\d{2}))?)?';

  /// Reads the day-first dates commonly emitted by Indian institutions.
  static const localDate = r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b';
}
