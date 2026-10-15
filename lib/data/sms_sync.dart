import 'package:flutter/services.dart';

import '../models/sms_sync/bank_sms.dart';

export '../models/sms_sync/bank_sms.dart';
export '../models/sms_sync/sms_sync_result.dart';

/// Dart interface to the platform channel that reads and schedules SMS sync.
///
/// Message interpretation deliberately lives in `sms_transaction_pipeline.dart`.
/// This class is only responsible for transporting SMS data into the app.
/// Native behavior is platform-specific and is not verified by this refactor.
class SmsSyncService {
  static const _channel = MethodChannel('yenma/sms');

  /// Reads messages in the optional half-open `[from, until)` time range.
  Future<List<BankSms>> read({DateTime? from, DateTime? until}) async {
    final values =
        await _channel.invokeListMethod<dynamic>('readMessages', {
          if (from != null) 'from': from.millisecondsSinceEpoch,
          if (until != null) 'until': until.millisecondsSinceEpoch,
        }) ??
        const [];

    return values
        .map((value) {
          final row = Map<String, dynamic>.from(value as Map);
          return BankSms(
            address: row['address'] as String,
            body: row['body'] as String,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
          );
        })
        .where((sms) {
          final afterStart = from == null || !sms.timestamp.isBefore(from);
          final beforeEnd = until == null || sms.timestamp.isBefore(until);
          return afterStart && beforeEnd;
        })
        .toList();
  }

  /// Requests the platform integration to register its daily sync schedule.
  Future<void> scheduleDaily() => _channel.invokeMethod('scheduleDailySync');
}
