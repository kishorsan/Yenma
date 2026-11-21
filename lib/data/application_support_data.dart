import 'package:sqflite/sqflite.dart';

import '../models/application_support/sms_sync_log_record.dart';

export '../models/application_support/sms_sync_log_record.dart';

/// Reads and writes cross-feature settings and synchronization diagnostics.
class ApplicationSupportRepository {
  const ApplicationSupportRepository(this.db);
  final Database db;

  /// Returns the stored string value for [key], or `null` when it is unset.
  Future<String?> setting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// Inserts or replaces an application setting.
  Future<void> saveSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Loads recent SMS sync runs, newest first, capped by [limit].
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
