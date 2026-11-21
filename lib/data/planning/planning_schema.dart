import 'package:sqflite/sqflite.dart';

/// Creates normalized monthly plans linked to the reusable plan-type catalogue.
Future<void> createPlanningSchema(DatabaseExecutor db) async {
  // One row represents one named plan and its remaining amount for a month.
  await db.execute('''CREATE TABLE IF NOT EXISTS money_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES plan_type(id) ON DELETE RESTRICT,
    note TEXT NOT NULL DEFAULT '',
    planned_amount INTEGER NOT NULL CHECK(planned_amount >= 0),
    remaining_amount INTEGER NOT NULL CHECK(remaining_amount >= 0 AND remaining_amount <= planned_amount),
    month_year TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''');
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS money_plans_month_type_note '
    'ON money_plans(month_year, plan_id, note)',
  );
}
