/// Read-only summary of a completed SMS import stored for diagnostics.
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
