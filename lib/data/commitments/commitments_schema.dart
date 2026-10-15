import 'package:sqflite/sqflite.dart';

/// Creates subscription, loan/EMI and repayment schedule storage.
Future<void> createCommitmentsSchema(DatabaseExecutor db) async {
  // Recurring subscriptions retain their billing cycle and notification state.
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
  // Loans and EMIs share one parent table and are distinguished by `is_emi`.
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
    is_emi INTEGER NOT NULL DEFAULT 0 CHECK(is_emi IN (0,1)),
    annual_interest_basis_points INTEGER CHECK(annual_interest_basis_points >= 0),
    regular_payment_paise INTEGER CHECK(regular_payment_paise > 0),
    installment_count INTEGER CHECK(installment_count > 0),
    first_due_date TEXT
  )''');
  await db.execute('CREATE INDEX IF NOT EXISTS loans_status ON loans(status)');
  // Each row records a dated principal/interest breakdown for a loan or EMI.
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
