import '../data/sms_sync.dart' show SmsSyncService;
import '../models/sms_sync/bank_sms.dart';

/// Prevents preview runs from reading or scheduling access to real SMS data.
class PreviewSmsSyncService extends SmsSyncService {
  @override
  Future<List<BankSms>> read({DateTime? from, DateTime? until}) async =>
      const [];

  @override
  Future<void> scheduleDaily() async {}
}
