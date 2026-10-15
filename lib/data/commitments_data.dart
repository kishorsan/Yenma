import 'package:sqflite/sqflite.dart';

import '../models/commitments/emi.dart';
import '../models/commitments/loan.dart';
import '../models/commitments/subscription.dart';
import 'commitments/repository_contracts.dart';

export '../models/commitments/emi.dart';
export '../models/commitments/loan.dart';
export '../models/commitments/subscription.dart';
export 'commitments/commitments_schema.dart';
export 'commitments/repository_contracts.dart';

/// SQLite implementation shared by subscriptions, EMIs and loans.
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

  /// Stores a tracking row and recalculates the parent loan's paid principal.
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
