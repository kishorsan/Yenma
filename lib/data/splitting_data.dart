import 'package:sqflite/sqflite.dart';

import '../domain/debt.dart';
import '../domain/money.dart';
import '../domain/split.dart';

Future<void> createSplittingSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS associate_group (
    group_id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_name TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''');
  await _addSplitColumn(
    db,
    'associate_group',
    'note',
    "TEXT NOT NULL DEFAULT ''",
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS associate_group_mapping (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL REFERENCES associate_group(group_id) ON DELETE CASCADE,
    associate_id INTEGER NOT NULL REFERENCES associates(id) ON DELETE RESTRICT,
    UNIQUE(group_id, associate_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS associate_group_mapping_associate '
    'ON associate_group_mapping(associate_id)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS split_allocation (
    allocation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    associate_group_id INTEGER REFERENCES associate_group(group_id) ON DELETE SET NULL,
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
    title TEXT NOT NULL DEFAULT 'Shared expense',
    paid_by_associate_id INTEGER REFERENCES associates(id) ON DELETE RESTRICT,
    note TEXT NOT NULL DEFAULT '',
    date TEXT NOT NULL
  )''');
  await _addSplitColumn(
    db,
    'split_allocation',
    'title',
    "TEXT NOT NULL DEFAULT 'Shared expense'",
  );
  await _addSplitColumn(
    db,
    'split_allocation',
    'paid_by_associate_id',
    'INTEGER',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_allocation_group '
    'ON split_allocation(associate_group_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_allocation_date ON split_allocation(date)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS split_allocation_mapping (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    allocation_id INTEGER NOT NULL REFERENCES split_allocation(allocation_id) ON DELETE CASCADE,
    associate_id INTEGER NOT NULL REFERENCES associates(id) ON DELETE RESTRICT,
    split_amount_paise INTEGER NOT NULL CHECK(split_amount_paise > 0),
    UNIQUE(allocation_id, associate_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_allocation_mapping_associate '
    'ON split_allocation_mapping(associate_id)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS split_allocation_share (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    allocation_id INTEGER NOT NULL REFERENCES split_allocation(allocation_id) ON DELETE CASCADE,
    associate_id INTEGER REFERENCES associates(id) ON DELETE RESTRICT,
    participant_name TEXT NOT NULL,
    is_me INTEGER NOT NULL DEFAULT 0 CHECK(is_me IN (0,1)),
    split_amount_paise INTEGER NOT NULL CHECK(split_amount_paise > 0),
    debt_id INTEGER REFERENCES debts(id) ON DELETE SET NULL,
    CHECK((is_me = 1 AND associate_id IS NULL) OR (is_me = 0 AND associate_id IS NOT NULL)),
    UNIQUE(allocation_id, associate_id)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS split_share_allocation '
    'ON split_allocation_share(allocation_id)',
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS split_share_one_me '
    'ON split_allocation_share(allocation_id) WHERE is_me = 1',
  );
}

Future<void> _addSplitColumn(
  DatabaseExecutor db,
  String table,
  String column,
  String definition,
) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  if (columns.any((row) => row['name'] == column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}

class SplitShare {
  const SplitShare({required this.associateId, required this.amountPaise});
  final int associateId;
  final int amountPaise;
}

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

class SplittingRepository {
  const SplittingRepository(this.db);
  final Database db;

  Future<int> createGroup(String name, Iterable<int> associateIds) =>
      db.transaction((txn) async {
        final groupId = await txn.insert('associate_group', {
          'group_name': name.trim(),
        });
        for (final associateId in associateIds.toSet()) {
          await txn.insert('associate_group_mapping', {
            'group_id': groupId,
            'associate_id': associateId,
          });
        }
        return groupId;
      });

  Future<int> saveAllocation(SplitAllocationRecord allocation) async {
    if (allocation.amountPaise <= 0 ||
        allocation.shares.isEmpty ||
        allocation.shares.any((share) => share.amountPaise <= 0) ||
        allocation.shares.fold<int>(
              0,
              (sum, share) => sum + share.amountPaise,
            ) !=
            allocation.amountPaise) {
      throw ArgumentError('Split shares must be positive and equal the total.');
    }
    return db.transaction((txn) async {
      if (allocation.associateGroupId != null) {
        final allowed = await txn.query(
          'associate_group_mapping',
          columns: ['associate_id'],
          where: 'group_id = ?',
          whereArgs: [allocation.associateGroupId],
        );
        final allowedIds = allowed
            .map((row) => row['associate_id'] as int)
            .toSet();
        if (allocation.shares.any(
          (share) => !allowedIds.contains(share.associateId),
        )) {
          throw ArgumentError(
            'Every split participant must belong to the group.',
          );
        }
      }
      final id =
          allocation.id ??
          await txn.insert('split_allocation', {
            'associate_group_id': allocation.associateGroupId,
            'amount_paise': allocation.amountPaise,
            'note': allocation.note.trim(),
            'date': allocation.date.toIso8601String(),
          });
      if (allocation.id != null) {
        await txn.update(
          'split_allocation',
          {
            'associate_group_id': allocation.associateGroupId,
            'amount_paise': allocation.amountPaise,
            'note': allocation.note.trim(),
            'date': allocation.date.toIso8601String(),
          },
          where: 'allocation_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'split_allocation_mapping',
          where: 'allocation_id = ?',
          whereArgs: [id],
        );
      }
      for (final share in allocation.shares) {
        await txn.insert('split_allocation_mapping', {
          'allocation_id': id,
          'associate_id': share.associateId,
          'split_amount_paise': share.amountPaise,
        });
      }
      return id;
    });
  }

  Future<void> deleteAllocation(int id) async {
    await db.delete(
      'split_allocation',
      where: 'allocation_id = ?',
      whereArgs: [id],
    );
  }
}

mixin SqliteSplitOperations implements SplitRepository {
  Database get splitDatabase;

  @override
  Future<List<SplitGroup>> splitGroups() async {
    final groups = await splitDatabase.rawQuery('''
      SELECT g.group_id, g.group_name, g.note, g.created_at,
        MAX(a.date) AS last_activity
      FROM associate_group g
      LEFT JOIN split_allocation a ON a.associate_group_id = g.group_id
      GROUP BY g.group_id
      ORDER BY COALESCE(MAX(a.date), g.created_at) DESC, g.group_id DESC
    ''');
    final result = <SplitGroup>[];
    for (final row in groups) {
      final members = await splitDatabase.rawQuery(
        '''
        SELECT a.id, a.name FROM associate_group_mapping gm
        JOIN associates a ON a.id = gm.associate_id
        WHERE gm.group_id = ? ORDER BY a.name COLLATE NOCASE
      ''',
        [row['group_id']],
      );
      result.add(
        SplitGroup(
          id: row['group_id'] as int,
          name: row['group_name'] as String,
          note: row['note'] as String,
          members: members
              .map(
                (member) => SplitMember(
                  id: member['id'] as int,
                  name: member['name'] as String,
                ),
              )
              .toList(),
          createdAt: DateTime.parse(row['created_at'] as String),
          lastActivity: row['last_activity'] == null
              ? null
              : DateTime.parse(row['last_activity'] as String),
        ),
      );
    }
    return result;
  }

  @override
  Future<int> createSplitGroup({
    required String name,
    required String note,
    required List<String> memberNames,
  }) async {
    final cleanName = name.trim();
    final membersByKey = <String, String>{};
    for (final value in memberNames) {
      final member = normalizePersonName(value);
      if (member.isNotEmpty) {
        membersByKey.putIfAbsent(personNameKey(member), () => member);
      }
    }
    final cleanMembers = membersByKey.values.toList();
    if (cleanName.isEmpty || cleanName.length > 80 || cleanMembers.isEmpty) {
      throw const SplitValidationException(
        'Enter a group name and at least one member.',
      );
    }
    return splitDatabase.transaction((db) async {
      final groupId = await db.insert('associate_group', {
        'group_name': cleanName,
        'note': note.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final member in cleanMembers) {
        await db.insert('debt_people', {
          'name_key': personNameKey(member),
          'name': member,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        var associates = await db.query(
          'associates',
          columns: ['id'],
          where: 'lower(trim(name)) = ?',
          whereArgs: [personNameKey(member)],
        );
        if (associates.isEmpty) {
          final id = await db.insert('associates', {'name': member});
          associates = [
            <String, Object?>{'id': id},
          ];
        }
        await db.insert('associate_group_mapping', {
          'group_id': groupId,
          'associate_id': associates.single['id'] as int,
        });
      }
      return groupId;
    });
  }

  @override
  Future<List<SplitEntry>> splitEntries(int groupId) async {
    final allocations = await splitDatabase.query(
      'split_allocation',
      where: 'associate_group_id = ?',
      whereArgs: [groupId],
      orderBy: 'date DESC, allocation_id DESC',
    );
    final result = <SplitEntry>[];
    for (final allocation in allocations) {
      final shares = await splitDatabase.rawQuery(
        '''
        SELECT s.associate_id, s.participant_name, s.is_me,
          s.split_amount_paise, s.debt_id,
          CASE WHEN s.debt_id IS NULL THEN NULL ELSE
            d.amount_paise - COALESCE(SUM(r.amount_paise), 0) END AS remaining_paise
        FROM split_allocation_share s
        LEFT JOIN debts d ON d.id = s.debt_id
        LEFT JOIN repayments r ON r.debt_id = d.id
        WHERE s.allocation_id = ?
        GROUP BY s.id ORDER BY s.is_me DESC, s.id ASC
      ''',
        [allocation['allocation_id']],
      );
      final payerId = allocation['paid_by_associate_id'] as int?;
      var payerName = 'Me';
      if (payerId != null) {
        final payer = await splitDatabase.query(
          'associates',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [payerId],
        );
        payerName = payer.isEmpty
            ? 'Group member'
            : payer.single['name'] as String;
      }
      result.add(
        SplitEntry(
          id: allocation['allocation_id'] as int,
          groupId: groupId,
          title: allocation['title'] as String,
          amountPaise: allocation['amount_paise'] as int,
          date: DateTime.parse(allocation['date'] as String),
          note: allocation['note'] as String,
          payerName: payerName,
          recordedForSomeoneElse: payerId != null,
          shares: shares
              .map(
                (share) => SplitEntryShare(
                  associateId: share['associate_id'] as int?,
                  name: share['participant_name'] as String,
                  isMe: share['is_me'] == 1,
                  amountPaise: share['split_amount_paise'] as int,
                  debtId: share['debt_id'] as int?,
                  remainingPaise: share['remaining_paise'] as int?,
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  @override
  Future<int> saveSplitEntry(SplitEntryDraft draft) async {
    if (draft.title.trim().isEmpty ||
        draft.amountPaise <= 0 ||
        draft.shares.isEmpty ||
        draft.shares.any((share) => share.amountPaise <= 0) ||
        draft.shares.fold<int>(0, (sum, share) => sum + share.amountPaise) !=
            draft.amountPaise) {
      throw const SplitValidationException(
        'Shares must be positive and add up to the total.',
      );
    }
    return splitDatabase.transaction((db) async {
      final groupRows = await db.query(
        'associate_group_mapping',
        columns: ['associate_id'],
        where: 'group_id = ?',
        whereArgs: [draft.groupId],
      );
      final memberIds = groupRows
          .map((row) => row['associate_id'] as int)
          .toSet();
      if (memberIds.isEmpty ||
          (draft.payerAssociateId != null &&
              !memberIds.contains(draft.payerAssociateId)) ||
          draft.shares.any(
            (share) => !share.isMe && !memberIds.contains(share.associateId),
          )) {
        throw const SplitValidationException(
          'The payer and participants must belong to this group.',
        );
      }
      final allocationId = await db.insert('split_allocation', {
        'associate_group_id': draft.groupId,
        'amount_paise': draft.amountPaise,
        'title': draft.title.trim(),
        'paid_by_associate_id': draft.payerAssociateId,
        'note': draft.note.trim(),
        'date': draft.date.toIso8601String(),
      });

      String? payerName;
      if (draft.payerAssociateId != null) {
        final payer = await db.query(
          'associates',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [draft.payerAssociateId],
        );
        payerName = payer.single['name'] as String;
      }
      for (final share in draft.shares) {
        int? debtId;
        if (draft.payerAssociateId == null && !share.isMe) {
          debtId = await _insertSplitDebt(
            db,
            associateId: share.associateId!,
            person: share.name,
            title: draft.title,
            amountPaise: share.amountPaise,
            direction: DebtDirection.owedToMe,
            date: draft.date,
            note: draft.note,
          );
        } else if (draft.payerAssociateId != null && share.isMe) {
          debtId = await _insertSplitDebt(
            db,
            associateId: draft.payerAssociateId!,
            person: payerName!,
            title: draft.title,
            amountPaise: share.amountPaise,
            direction: DebtDirection.iOwe,
            date: draft.date,
            note: draft.note,
          );
        }
        await db.insert('split_allocation_share', {
          'allocation_id': allocationId,
          'associate_id': share.isMe ? null : share.associateId,
          'participant_name': share.isMe ? 'Me' : share.name,
          'is_me': share.isMe ? 1 : 0,
          'split_amount_paise': share.amountPaise,
          'debt_id': debtId,
        });
      }
      return allocationId;
    });
  }

  Future<int> _insertSplitDebt(
    DatabaseExecutor db, {
    required int associateId,
    required String person,
    required String title,
    required int amountPaise,
    required DebtDirection direction,
    required DateTime date,
    required String note,
  }) async {
    await db.insert('debt_people', {
      'name_key': personNameKey(person),
      'name': normalizePersonName(person),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return db.insert('debts', {
      'transaction_id': null,
      'person': normalizePersonName(person),
      'title': title.trim(),
      'amount_paise': amountPaise,
      'direction': direction.name,
      'date': dateKey(date),
      'note': note.trim(),
      'has_receipt': 0,
      'associate_id': associateId,
      'debt_type': 'SPLIT',
    });
  }
}
