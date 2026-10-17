import 'package:sqflite/sqflite.dart';

import '../models/reference_data/associate_record.dart';
import '../models/reference_data/bank_record.dart';
import '../models/reference_data/plan_type_record.dart';

export '../models/reference_data/associate_record.dart';
export '../models/reference_data/bank_record.dart';
export '../models/reference_data/plan_type_record.dart';
export 'reference_data/reference_data_schema.dart';

/// Maintains reusable banks, associates and plan-type reference records.
class ReferenceDataRepository {
  const ReferenceDataRepository(this.db);
  final Database db;

  /// Loads banks alphabetically by their display name.
  Future<List<BankRecord>> banks() async =>
      (await db.query('banks', orderBy: 'bank_name COLLATE NOCASE'))
          .map(
            (row) => BankRecord(
              id: row['id'] as int,
              name: row['bank_name'] as String,
              code: row['bank_code'] as String,
              isTracked: row['is_tracked'] == 1,
              isCreditCard: row['is_credit_card'] == 1,
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .toList();

  /// Inserts or replaces a bank reference and returns its identifier.
  Future<int> saveBank(BankRecord bank) => db.insert('banks', {
    if (bank.id != null) 'id': bank.id,
    'bank_name': bank.name.trim(),
    'bank_code': bank.code.trim(),
    'is_tracked': bank.isTracked ? 1 : 0,
    'is_credit_card': bank.isCreditCard ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Loads people available to debt and split features.
  Future<List<AssociateRecord>> associates() async =>
      (await db.query('associates', orderBy: 'name COLLATE NOCASE'))
          .map(
            (row) => AssociateRecord(
              id: row['id'] as int,
              name: row['name'] as String,
              phoneNumber: row['phone_number'] as String?,
            ),
          )
          .toList();

  /// Inserts or replaces an associate and returns its identifier.
  Future<int> saveAssociate(AssociateRecord associate) =>
      db.insert('associates', {
        if (associate.id != null) 'id': associate.id,
        'name': associate.name.trim(),
        'phone_number': associate.phoneNumber?.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Loads reusable plan types in insertion order.
  Future<List<PlanTypeRecord>> planTypes() async =>
      (await db.query('plan_type', orderBy: 'id ASC'))
          .map(
            (row) => PlanTypeRecord(
              id: row['id'] as int,
              plan: row['plan'] as String,
            ),
          )
          .toList();
}
