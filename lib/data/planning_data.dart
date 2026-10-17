import 'package:sqflite/sqflite.dart';

import '../domain/monthly_plan.dart';
import '../models/planning/money_plan_record.dart';

export '../models/planning/money_plan_record.dart';
export 'planning/planning_schema.dart';

/// Maps normalized planning rows to persistence and feature-domain models.
class PlanningRepository {
  const PlanningRepository(this.db);
  final Database db;

  /// Loads raw persistence records for a `YYYY-MM` month key.
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

  /// Inserts or replaces a raw normalized plan record.
  Future<int> save(MoneyPlanRecord plan) => db.insert('money_plans', {
    if (plan.id != null) 'id': plan.id,
    'plan_id': plan.planId,
    'note': plan.note.trim(),
    'planned_amount': plan.plannedAmount,
    'remaining_amount': plan.remainingAmount,
    'month_year': plan.monthYear,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Deletes the plan identified by [id].
  Future<void> delete(int id) async {
    await db.delete('money_plans', where: 'id = ?', whereArgs: [id]);
  }

  /// Loads feature models joined with their reusable plan-type names.
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

  /// Loads plan types that have been used, sorted for form suggestions.
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

  /// Validates and stores a plan, creating its plan type when necessary.
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
