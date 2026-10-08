import 'package:sqflite/sqflite.dart';

class BankRecord {
  const BankRecord({
    this.id,
    required this.name,
    required this.code,
    this.isTracked = true,
    this.isCreditCard = false,
    this.createdAt,
  });
  final int? id;
  final String name;
  final String code;
  final bool isTracked;
  final bool isCreditCard;
  final DateTime? createdAt;
}

class AssociateRecord {
  const AssociateRecord({this.id, required this.name, this.phoneNumber});
  final int? id;
  final String name;
  final String? phoneNumber;
}

class PlanTypeRecord {
  const PlanTypeRecord({this.id, required this.plan});
  final int? id;
  final String plan;
}

Future<void> createReferenceDataSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS banks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bank_name TEXT NOT NULL,
    bank_code TEXT NOT NULL UNIQUE,
    is_tracked INTEGER NOT NULL DEFAULT 1 CHECK(is_tracked IN (0,1)),
    is_credit_card INTEGER NOT NULL DEFAULT 0 CHECK(is_credit_card IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS associates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL CHECK(length(trim(name)) > 0),
    phone_number TEXT UNIQUE
  )''');
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS associates_normalized_name '
    'ON associates(lower(trim(name)))',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS plan_type (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan TEXT NOT NULL UNIQUE
  )''');
}

class ReferenceDataRepository {
  const ReferenceDataRepository(this.db);
  final Database db;

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

  Future<int> saveBank(BankRecord bank) => db.insert('banks', {
    if (bank.id != null) 'id': bank.id,
    'bank_name': bank.name.trim(),
    'bank_code': bank.code.trim(),
    'is_tracked': bank.isTracked ? 1 : 0,
    'is_credit_card': bank.isCreditCard ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

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

  Future<int> saveAssociate(AssociateRecord associate) =>
      db.insert('associates', {
        if (associate.id != null) 'id': associate.id,
        'name': associate.name.trim(),
        'phone_number': associate.phoneNumber?.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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
