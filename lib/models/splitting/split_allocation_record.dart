/// One associate's contribution to a persisted split allocation.
class SplitShare {
  const SplitShare({required this.associateId, required this.amountPaise});

  final int associateId;
  final int amountPaise;
}

/// Persistence model for an allocation and all of its participant shares.
class SplitAllocationRecord {
  const SplitAllocationRecord({
    this.id,
    this.associateGroupId,
    required this.amountPaise,
    required this.date,
    this.note = '',
    this.shares = const [],
  });

  final int? id;
  final int? associateGroupId;
  final int amountPaise;
  final DateTime date;
  final String note;
  final List<SplitShare> shares;
}
