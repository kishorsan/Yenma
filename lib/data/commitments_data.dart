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
    emi_name TEXT NOT NULL DEFAULT 'EMI',
    total_amount_paise INTEGER NOT NULL CHECK(total_amount_paise > 0),
    amount_paid_paise INTEGER NOT NULL DEFAULT 0 CHECK(amount_paid_paise >= 0),
    processing_fee_paise INTEGER NOT NULL DEFAULT 0 CHECK(processing_fee_paise >= 0),
    billing_day INTEGER NOT NULL DEFAULT 1 CHECK(billing_day BETWEEN 1 AND 28),
    emi_ownership TEXT NOT NULL DEFAULT 'MINE' CHECK(emi_ownership IN ('MINE','THROUGH_ME')),
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
    gst_paise INTEGER NOT NULL DEFAULT 0 CHECK(gst_paise >= 0),
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

enum EmiOwnership { mine, throughMe }

abstract interface class SubscriptionRepository {
  Future<int> saveSubscription(SubscriptionRecord value);
  Future<List<SubscriptionRecord>> subscriptions({bool? active});
}

abstract interface class EmiRepository {
  Future<int> saveEmi(EmiRecord value);
  Future<List<EmiRecord>> emis();
  Future<List<EmiInstallment>> emiInstallments(int emiId);
  Future<void> saveEmiInstallment({
    int? id,
    required int emiId,
    required int principalPaise,
    required int interestPaise,
    required DateTime date,
    required bool isPaid,
  });
  Future<int> loadGstBasisPoints();
  Future<void> saveGstBasisPoints(int basisPoints);
}

abstract interface class LoanRepository {
  Future<int> saveLoan(LoanRecord value);
  Future<List<LoanRecord>> loans();
  Future<List<LoanTrackingRecord>> loanPayments(int loanId);
  Future<void> saveLoanPayment(LoanTrackingRecord value);
}

class EmiRecord {
  const EmiRecord({
    this.id,
    required this.name,
    required this.principalPaise,
    this.paidPrincipalPaise = 0,
    this.processingFeePaise = 0,
    required this.billingDay,
    required this.startDate,
    this.endDate,
    this.note = '',
    this.ownership = EmiOwnership.mine,
  });

  final int? id;
  final String name;
  final int principalPaise;
  final int paidPrincipalPaise;
  final int processingFeePaise;
  final int billingDay;
  final DateTime startDate;
  final DateTime? endDate;
  final String note;
  final EmiOwnership ownership;

  int get remainingPaise =>
      (principalPaise - paidPrincipalPaise).clamp(0, principalPaise);
  bool get isComplete => remainingPaise == 0;
}

class EmiInstallment {
  const EmiInstallment({
    this.id,
    required this.emiId,
    required this.principalPaise,
    required this.interestPaise,
    required this.gstPaise,
    required this.date,
    required this.isPaid,
  });

  final int? id;
  final int emiId;
  final int principalPaise;
  final int interestPaise;
  final int gstPaise;
  final DateTime date;
  final bool isPaid;
  int get totalPaise => principalPaise + interestPaise + gstPaise;
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
    this.name = 'Loan',
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
  final String name;
  final int totalAmountPaise;
  final int amountPaidPaise;
  final String note;
  final DateTime startDate;
  final DateTime? endDate;
  final LoanStatus status;
  final LoanType type;
  final bool isEmi;

  int get remainingPaise =>
      (totalAmountPaise - amountPaidPaise).clamp(0, totalAmountPaise);
  bool get isComplete => remainingPaise == 0;
}

class LoanTrackingRecord {
  const LoanTrackingRecord({
    this.id,
    required this.loanId,
    required this.principalPaise,
    required this.interestPaise,
    this.gstPaise = 0,
    required this.date,
    this.isPaid = false,
  });
  final int? id;
  final int loanId;
  final int principalPaise;
  final int interestPaise;
  final int gstPaise;
  final DateTime date;
  final bool isPaid;
}

class CommitmentsRepository
    implements SubscriptionRepository, EmiRepository, LoanRepository {
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

  @override
  Future<int> saveLoan(LoanRecord value) async {
    if (value.name.trim().isEmpty ||
        value.totalAmountPaise <= 0 ||
        value.amountPaidPaise < 0 ||
        value.amountPaidPaise > value.totalAmountPaise ||
        (value.endDate != null && value.endDate!.isBefore(value.startDate))) {
      throw ArgumentError('Invalid loan');
    }
    final row = <String, Object?>{
      'emi_name': value.name.trim(),
      'total_amount_paise': value.totalAmountPaise,
      'amount_paid_paise': value.amountPaidPaise,
      'note': value.note.trim(),
      'start_date': value.startDate.toIso8601String(),
      'end_date': value.endDate?.toIso8601String(),
      'status': value.isComplete ? 'FULLY_PAID' : 'PENDING',
      'loan_type': switch (value.type) {
        LoanType.revolving => 'REVOLVING',
        LoanType.oneTime => 'ONE_TIME',
        LoanType.emiAmortizing => 'EMI_AMORTIZING',
      },
      'is_emi': value.isEmi ? 1 : 0,
    };
    if (value.id == null) return db.insert('loans', row);
    await db.update('loans', row, where: 'id = ?', whereArgs: [value.id]);
    return value.id!;
  }

  @override
  Future<List<LoanRecord>> loans() async => (await db.query(
    'loans',
    where: 'is_emi = 0',
    orderBy: "CASE status WHEN 'PENDING' THEN 0 ELSE 1 END, start_date DESC, id DESC",
  )).map(_loanFromRow).toList();

  LoanRecord _loanFromRow(Map<String, Object?> row) => LoanRecord(
    id: row['id'] as int,
    name: row['emi_name'] as String,
    totalAmountPaise: row['total_amount_paise'] as int,
    amountPaidPaise: row['amount_paid_paise'] as int,
    note: row['note'] as String,
    startDate: DateTime.parse(row['start_date'] as String),
    endDate: row['end_date'] == null
        ? null
        : DateTime.parse(row['end_date'] as String),
    status: row['status'] == 'FULLY_PAID'
        ? LoanStatus.fullyPaid
        : LoanStatus.pending,
    type: switch (row['loan_type']) {
      'REVOLVING' => LoanType.revolving,
      'ONE_TIME' => LoanType.oneTime,
      _ => LoanType.emiAmortizing,
    },
  );

  @override
  Future<List<LoanTrackingRecord>> loanPayments(int loanId) async =>
      (await db.query(
            'loan_tracking',
            where: 'loan_id = ?',
            whereArgs: [loanId],
            orderBy: 'date DESC, id DESC',
          ))
          .map(
            (row) => LoanTrackingRecord(
              id: row['id'] as int,
              loanId: row['loan_id'] as int,
              principalPaise: row['principal_paise'] as int,
              interestPaise: row['interest_paise'] as int,
              gstPaise: row['gst_paise'] as int,
              date: DateTime.parse(row['date'] as String),
              isPaid: row['is_paid'] == 1,
            ),
          )
          .toList();

  @override
  Future<void> saveLoanPayment(LoanTrackingRecord value) async {
    if (value.principalPaise < 0 ||
        value.interestPaise < 0 ||
        value.gstPaise < 0 ||
        value.principalPaise + value.interestPaise + value.gstPaise <= 0) {
      throw ArgumentError('Invalid loan payment');
    }
    final records = await db.query(
      'loans',
      columns: ['start_date', 'end_date'],
      where: 'id = ? AND is_emi = 0',
      whereArgs: [value.loanId],
      limit: 1,
    );
    if (records.isEmpty) throw StateError('Loan no longer exists');
    final start = DateTime.parse(records.single['start_date'] as String);
    final endValue = records.single['end_date'] as String?;
    final end = endValue == null ? null : DateTime.parse(endValue);
    if (value.date.isBefore(start) ||
        (end != null && value.date.isAfter(end))) {
      throw ArgumentError('Payment date is outside the loan date range');
    }
    await saveLoanTracking(value);
  }

  Future<void> saveLoanTracking(LoanTrackingRecord value) async {
    await db.transaction((txn) async {
      await txn.insert('loan_tracking', {
        if (value.id != null) 'id': value.id,
        'loan_id': value.loanId,
        'principal_paise': value.principalPaise,
        'interest_paise': value.interestPaise,
        'gst_paise': value.gstPaise,
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

  @override
  Future<int> saveEmi(EmiRecord value) async {
    if (value.name.trim().isEmpty ||
        value.principalPaise <= 0 ||
        value.paidPrincipalPaise > value.principalPaise ||
        value.processingFeePaise < 0 ||
        value.billingDay < 1 ||
        value.billingDay > 28 ||
        (value.endDate != null && value.endDate!.isBefore(value.startDate))) {
      throw ArgumentError('Invalid EMI');
    }
    final row = <String, Object?>{
      'emi_name': value.name.trim(),
      'total_amount_paise': value.principalPaise,
      'processing_fee_paise': value.processingFeePaise,
      'billing_day': value.billingDay,
      'emi_ownership': value.ownership == EmiOwnership.mine
          ? 'MINE'
          : 'THROUGH_ME',
      'note': value.note.trim(),
      'start_date': value.startDate.toIso8601String(),
      'end_date': value.endDate?.toIso8601String(),
      'status': value.isComplete ? 'FULLY_PAID' : 'PENDING',
      'loan_type': 'EMI_AMORTIZING',
      'is_emi': 1,
    };
    if (value.id == null) return db.insert('loans', row);
    await db.update('loans', row, where: 'id = ?', whereArgs: [value.id]);
    return value.id!;
  }

  @override
  Future<List<EmiRecord>> emis() async =>
      (await db.query(
            'loans',
            where: 'is_emi = 1',
            orderBy: "CASE status WHEN 'PENDING' THEN 0 ELSE 1 END, start_date DESC, id DESC",
          ))
          .map(
            (row) => EmiRecord(
              id: row['id'] as int,
              name: row['emi_name'] as String,
              principalPaise: row['total_amount_paise'] as int,
              paidPrincipalPaise: row['amount_paid_paise'] as int,
              processingFeePaise: row['processing_fee_paise'] as int,
              billingDay: row['billing_day'] as int,
              startDate: DateTime.parse(row['start_date'] as String),
              endDate: row['end_date'] == null
                  ? null
                  : DateTime.parse(row['end_date'] as String),
              note: row['note'] as String,
              ownership: row['emi_ownership'] == 'THROUGH_ME'
                  ? EmiOwnership.throughMe
                  : EmiOwnership.mine,
            ),
          )
          .toList();

  @override
  Future<List<EmiInstallment>> emiInstallments(int emiId) async =>
      (await db.query(
            'loan_tracking',
            where: 'loan_id = ?',
            whereArgs: [emiId],
            orderBy: 'date DESC, id DESC',
          ))
          .map(
            (row) => EmiInstallment(
              id: row['id'] as int,
              emiId: row['loan_id'] as int,
              principalPaise: row['principal_paise'] as int,
              interestPaise: row['interest_paise'] as int,
              gstPaise: row['gst_paise'] as int,
              date: DateTime.parse(row['date'] as String),
              isPaid: row['is_paid'] == 1,
            ),
          )
          .toList();

  @override
  Future<void> saveEmiInstallment({
    int? id,
    required int emiId,
    required int principalPaise,
    required int interestPaise,
    required DateTime date,
    required bool isPaid,
  }) async {
    if (principalPaise < 0 ||
        interestPaise < 0 ||
        principalPaise + interestPaise <= 0 ||
        date.day > 28) {
      throw ArgumentError('Invalid EMI instalment');
    }
    final loans = await db.query(
      'loans',
      columns: ['start_date', 'end_date'],
      where: 'id = ? AND is_emi = 1',
      whereArgs: [emiId],
      limit: 1,
    );
    if (loans.isEmpty) throw StateError('EMI no longer exists');
    final start = DateTime.parse(loans.single['start_date'] as String);
    final endValue = loans.single['end_date'] as String?;
    final end = endValue == null ? null : DateTime.parse(endValue);
    if (date.isBefore(start) || (end != null && date.isAfter(end))) {
      throw ArgumentError('EMI date is outside its date range');
    }
    final gstBasisPoints = await loadGstBasisPoints();
    final gstPaise = (interestPaise * gstBasisPoints + 5000) ~/ 10000;
    await saveLoanTracking(
      LoanTrackingRecord(
        id: id,
        loanId: emiId,
        principalPaise: principalPaise,
        interestPaise: interestPaise,
        gstPaise: gstPaise,
        date: date,
        isPaid: isPaid,
      ),
    );
  }

  @override
  Future<int> loadGstBasisPoints() async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['emi_gst_basis_points'],
      limit: 1,
    );
    return rows.isEmpty
        ? 1800
        : int.tryParse(rows.single['value'] as String) ?? 1800;
  }

  @override
  Future<void> saveGstBasisPoints(int basisPoints) async {
    if (basisPoints < 0 || basisPoints > 10000) {
      throw ArgumentError('GST must be between 0% and 100%');
    }
    await db.insert('settings', {
      'key': 'emi_gst_basis_points',
      'value': '$basisPoints',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
