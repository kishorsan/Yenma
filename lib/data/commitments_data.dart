import 'package:sqflite/sqflite.dart';

Future<void> createCommitmentsSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subscription_name TEXT NOT NULL,
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
    subscription_date INTEGER NOT NULL CHECK(subscription_date BETWEEN 1 AND 28),
    billing_month INTEGER NOT NULL DEFAULT 1 CHECK(billing_month BETWEEN 1 AND 12),
    type INTEGER NOT NULL CHECK(type IN (0,1)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
    notify_me INTEGER NOT NULL DEFAULT 0 CHECK(notify_me IN (0,1)),
    subscription_link TEXT
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS subscriptions_active_billing_day '
    'ON subscriptions(is_active, subscription_date)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS loans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    total_amount_paise INTEGER NOT NULL CHECK(total_amount_paise > 0),
    amount_paid_paise INTEGER NOT NULL DEFAULT 0 CHECK(amount_paid_paise >= 0),
    note TEXT NOT NULL DEFAULT '',
    start_date TEXT NOT NULL,
    end_date TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','FULLY_PAID')),
    loan_type TEXT NOT NULL CHECK(loan_type IN ('REVOLVING','ONE_TIME','EMI_AMORTIZING')),
    is_emi INTEGER NOT NULL DEFAULT 0 CHECK(is_emi IN (0,1))
  )''');
  await db.execute('CREATE INDEX IF NOT EXISTS loans_status ON loans(status)');
  await db.execute('''CREATE TABLE IF NOT EXISTS loan_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    loan_id INTEGER NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    principal_paise INTEGER NOT NULL CHECK(principal_paise >= 0),
    interest_paise INTEGER NOT NULL CHECK(interest_paise >= 0),
    date TEXT NOT NULL,
    is_paid INTEGER NOT NULL DEFAULT 0 CHECK(is_paid IN (0,1)),
    UNIQUE(loan_id, date)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS loan_tracking_payment_schedule '
    'ON loan_tracking(is_paid, date)',
  );
}

enum SubscriptionPeriod { monthly, yearly }

enum LoanStatus { pending, fullyPaid }

enum LoanType { revolving, oneTime, emiAmortizing }

abstract interface class SubscriptionRepository {
  Future<int> saveSubscription(SubscriptionRecord value);
  Future<List<SubscriptionRecord>> subscriptions({bool? active});
}

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

class LoanRecord {
  const LoanRecord({
    this.id,
    required this.totalAmountPaise,
    this.amountPaidPaise = 0,
    this.note = '',
    required this.startDate,
    this.endDate,
    this.status = LoanStatus.pending,
    required this.type,
    this.isEmi = false,
  });
  final int? id;
  final int totalAmountPaise;
  final int amountPaidPaise;
  final String note;
  final DateTime startDate;
  final DateTime? endDate;
  final LoanStatus status;
  final LoanType type;
  final bool isEmi;
}

class LoanTrackingRecord {
  const LoanTrackingRecord({
    this.id,
    required this.loanId,
    required this.principalPaise,
    required this.interestPaise,
    required this.date,
    this.isPaid = false,
  });
  final int? id;
  final int loanId;
  final int principalPaise;
  final int interestPaise;
  final DateTime date;
  final bool isPaid;
}

class CommitmentsRepository implements SubscriptionRepository {
  const CommitmentsRepository(this.db);
  final Database db;

  @override
  Future<int> saveSubscription(SubscriptionRecord value) =>
      db.insert('subscriptions', {
        if (value.id != null) 'id': value.id,
        'subscription_name': value.name.trim(),
        'amount_paise': value.amountPaise,
        'subscription_date': value.billingDay,
        'billing_month': value.billingMonth,
        'type': value.period.index,
        'is_active': value.isActive ? 1 : 0,
        'notify_me': value.notifyMe ? 1 : 0,
        'subscription_link': value.link,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<SubscriptionRecord>> subscriptions({bool? active}) async =>
      (await db.query(
            'subscriptions',
            where: active == null ? null : 'is_active = ?',
            whereArgs: active == null ? null : [active ? 1 : 0],
            orderBy: 'subscription_date ASC, id ASC',
          ))
          .map(
            (row) => SubscriptionRecord(
              id: row['id'] as int,
              name: row['subscription_name'] as String,
              amountPaise: row['amount_paise'] as int,
              billingDay: row['subscription_date'] as int,
              billingMonth: row['billing_month'] as int,
              period: SubscriptionPeriod.values[row['type'] as int],
              isActive: row['is_active'] == 1,
              notifyMe: row['notify_me'] == 1,
              link: row['subscription_link'] as String?,
            ),
          )
          .toList();

  Future<int> saveLoan(LoanRecord value) => db.insert('loans', {
    if (value.id != null) 'id': value.id,
    'total_amount_paise': value.totalAmountPaise,
    'amount_paid_paise': value.amountPaidPaise,
    'note': value.note.trim(),
    'start_date': value.startDate.toIso8601String(),
    'end_date': value.endDate?.toIso8601String(),
    'status': value.status == LoanStatus.pending ? 'PENDING' : 'FULLY_PAID',
    'loan_type': switch (value.type) {
      LoanType.revolving => 'REVOLVING',
      LoanType.oneTime => 'ONE_TIME',
      LoanType.emiAmortizing => 'EMI_AMORTIZING',
    },
    'is_emi': value.isEmi ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveLoanTracking(LoanTrackingRecord value) async {
    await db.transaction((txn) async {
      await txn.insert('loan_tracking', {
        if (value.id != null) 'id': value.id,
        'loan_id': value.loanId,
        'principal_paise': value.principalPaise,
        'interest_paise': value.interestPaise,
        'date': value.date.toIso8601String(),
        'is_paid': value.isPaid ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final paid = await txn.rawQuery(
        'SELECT COALESCE(SUM(principal_paise),0) total FROM loan_tracking '
        'WHERE loan_id = ? AND is_paid = 1',
        [value.loanId],
      );
      final total = await txn.query(
        'loans',
        columns: ['total_amount_paise'],
        where: 'id = ?',
        whereArgs: [value.loanId],
      );
      if (total.isEmpty) throw StateError('Loan no longer exists');
      final paidPaise = paid.single['total'] as int;
      if (paidPaise > (total.single['total_amount_paise'] as int)) {
        throw ArgumentError('Paid principal cannot exceed the loan total.');
      }
      await txn.update(
        'loans',
        {
          'amount_paid_paise': paidPaise,
          'status': paidPaise >= (total.single['total_amount_paise'] as int)
              ? 'FULLY_PAID'
              : 'PENDING',
        },
        where: 'id = ?',
        whereArgs: [value.loanId],
      );
    });
  }
}
