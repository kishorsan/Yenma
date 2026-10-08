class SplitMember {
  const SplitMember({required this.id, required this.name});

  final int id;
  final String name;
}

class SplitGroup {
  const SplitGroup({
    required this.id,
    required this.name,
    required this.note,
    required this.members,
    required this.createdAt,
    this.lastActivity,
  });

  final int id;
  final String name;
  final String note;
  final List<SplitMember> members;
  final DateTime createdAt;
  final DateTime? lastActivity;
}

class SplitEntryShare {
  const SplitEntryShare({
    this.associateId,
    required this.name,
    required this.isMe,
    required this.amountPaise,
    this.debtId,
    this.remainingPaise,
  });

  final int? associateId;
  final String name;
  final bool isMe;
  final int amountPaise;
  final int? debtId;
  final int? remainingPaise;
}

class SplitEntry {
  const SplitEntry({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amountPaise,
    required this.date,
    required this.note,
    required this.payerName,
    required this.recordedForSomeoneElse,
    required this.shares,
  });

  final int id;
  final int groupId;
  final String title;
  final int amountPaise;
  final DateTime date;
  final String note;
  final String payerName;
  final bool recordedForSomeoneElse;
  final List<SplitEntryShare> shares;
}

class SplitEntryDraft {
  const SplitEntryDraft({
    required this.groupId,
    required this.title,
    required this.amountPaise,
    required this.date,
    required this.payerAssociateId,
    required this.shares,
    this.note = '',
  });

  final int groupId;
  final String title;
  final int amountPaise;
  final DateTime date;
  final int? payerAssociateId;
  final List<SplitEntryShare> shares;
  final String note;
}

class SplitValidationException implements Exception {
  const SplitValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class SplitRepository {
  Future<List<SplitGroup>> splitGroups();
  Future<int> createSplitGroup({
    required String name,
    required String note,
    required List<String> memberNames,
  });
  Future<List<SplitEntry>> splitEntries(int groupId);
  Future<int> saveSplitEntry(SplitEntryDraft draft);
}
