import 'package:sqflite/sqflite.dart';

class SmsSyncLogRecord {
  const SmsSyncLogRecord({
    required this.id,
    required this.completedAt,
    required this.imported,
    required this.automatic,
  });
  final int id;
  final DateTime completedAt;
  final int imported;
  final bool automatic;
}

class ApplicationSupportRepository {
  const ApplicationSupportRepository(this.db);
  final Database db;

  Future<String?> setting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> saveSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SmsSyncLogRecord>> smsSyncHistory({int limit = 50}) async =>
      (await db.query(
            'sms_sync_log',
            orderBy: 'completed_at DESC, id DESC',
            limit: limit,
          ))
          .map(
            (row) => SmsSyncLogRecord(
              id: row['id'] as int,
              completedAt: DateTime.parse(row['completed_at'] as String),
              imported: row['imported'] as int,
              automatic: row['automatic'] == 1,
            ),
          )
          .toList();
}
