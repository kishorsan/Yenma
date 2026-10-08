import 'package:sqflite/sqflite.dart';

import '../domain/monthly_plan.dart';

Future<void> createPlanningSchema(DatabaseExecutor db) async {
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

class MoneyPlanRecord {
  const MoneyPlanRecord({
    this.id,
    required this.planId,
    required this.plannedAmount,
    required this.remainingAmount,
    required this.monthYear,
    this.note = '',
    this.createdAt,
  });
  final int? id;
  final int planId;
  final int plannedAmount;
  final int remainingAmount;
  final String monthYear;
  final String note;
  final DateTime? createdAt;
}

class PlanningRepository {
  const PlanningRepository(this.db);
  final Database db;

  Future<List<MoneyPlanRecord>> plansForMonth(String monthYear) async =>
      (await db.query(
            'money_plans',
            where: 'month_year = ?',
            whereArgs: [monthYear],
            orderBy: 'id ASC',
          ))
          .map(
            (row) => MoneyPlanRecord(
              id: row['id'] as int,
              planId: row['plan_id'] as int,
              plannedAmount: row['planned_amount'] as int,
              remainingAmount: row['remaining_amount'] as int,
              monthYear: row['month_year'] as String,
              note: row['note'] as String,
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .toList();

  Future<int> save(MoneyPlanRecord plan) => db.insert('money_plans', {
    if (plan.id != null) 'id': plan.id,
    'plan_id': plan.planId,
    'note': plan.note.trim(),
    'planned_amount': plan.plannedAmount,
    'remaining_amount': plan.remainingAmount,
    'month_year': plan.monthYear,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> delete(int id) async {
    await db.delete('money_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MoneyPlan>> plansWithTypesForMonth(String monthYear) async =>
      (await db.rawQuery(
        '''SELECT mp.id, mp.plan_id, pt.plan, mp.note, mp.planned_amount,
                  mp.remaining_amount,
                  mp.month_year, mp.created_at
           FROM money_plans mp
           JOIN plan_type pt ON pt.id = mp.plan_id
           WHERE mp.month_year = ?
           ORDER BY mp.id DESC''',
        [monthYear],
      )).map(_moneyPlanFromRow).toList();

  Future<List<PlanType>> planTypeSuggestions() async =>
      (await db.rawQuery('''SELECT DISTINCT pt.id, pt.plan
           FROM plan_type pt
           JOIN money_plans mp ON mp.plan_id = pt.id
           ORDER BY pt.plan COLLATE NOCASE ASC'''))
          .map(
            (row) =>
                PlanType(id: row['id'] as int, name: row['plan'] as String),
          )
          .toList();

  Future<void> savePlan(MoneyPlan plan) async {
    final name = plan.planName.trim();
    if (name.isEmpty ||
        plan.plannedPaise <= 0 ||
        plan.remainingPaise < 0 ||
        plan.remainingPaise > plan.plannedPaise) {
      throw ArgumentError('A plan needs valid total and remaining amounts');
    }
    await db.transaction((txn) async {
      var planId = plan.planTypeId;
      if (planId != null) {
        final matching = await txn.query(
          'plan_type',
          columns: ['id'],
          where: 'id = ? AND lower(trim(plan)) = lower(?)',
          whereArgs: [planId, name],
          limit: 1,
        );
        if (matching.isEmpty) planId = null;
      }
      if (planId == null) {
        final existing = await txn.query(
          'plan_type',
          columns: ['id'],
          where: 'lower(trim(plan)) = lower(?)',
          whereArgs: [name],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          planId = existing.single['id'] as int;
        } else {
          planId = await txn.insert('plan_type', {'plan': name});
        }
      }
      final values = <String, Object?>{
        'plan_id': planId,
        'note': plan.note.trim(),
        'planned_amount': plan.plannedPaise,
        'remaining_amount': plan.remainingPaise,
        'month_year': monthYearKey(plan.month),
      };
      if (plan.id == null) {
        await txn.insert('money_plans', values);
      } else {
        final updated = await txn.update(
          'money_plans',
          values,
          where: 'id = ?',
          whereArgs: [plan.id],
        );
        if (updated == 0) throw StateError('Plan no longer exists');
      }
    });
  }

  MoneyPlan _moneyPlanFromRow(Map<String, Object?> row) => MoneyPlan(
    id: row['id'] as int,
    planTypeId: row['plan_id'] as int,
    planName: row['plan'] as String,
    month: DateTime.parse('${row['month_year'] as String}-01'),
    plannedPaise: row['planned_amount'] as int,
    remainingPaise: row['remaining_amount'] as int,
    note: row['note'] as String,
    createdAt: DateTime.tryParse(row['created_at'] as String),
  );
}
