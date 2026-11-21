/// Summary of one completed SMS synchronization run.
class SmsSyncResult {
  const SmsSyncResult(this.imported, this.scanned, this.timestamp);

  final int imported;
  final int scanned;
  final DateTime timestamp;
}
