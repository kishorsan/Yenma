import '../data/money_repository.dart';
import '../domain/split.dart';

/// Creates groups where the user and another member each act as payer.
Future<void> seedSplitPreviewData(
  SqliteMoneyRepository repository,
  DateTime anchor,
) async {
  final tripId = await repository.createSplitGroup(
    name: 'Goa weekend',
    note: 'Travel, stay and food',
    memberNames: const ['Asha', 'Rahul'],
  );
  final trip = (await repository.splitGroups()).firstWhere(
    (group) => group.id == tripId,
  );
  final asha = trip.members.firstWhere((member) => member.name == 'Asha');
  final rahul = trip.members.firstWhere((member) => member.name == 'Rahul');
  await repository.saveSplitEntry(
    SplitEntryDraft(
      groupId: tripId,
      title: 'Beachside hotel',
      amountPaise: 900000,
      date: anchor.subtract(const Duration(days: 18)),
      payerAssociateId: null,
      note: 'Two nights',
      shares: [
        const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 300000),
        SplitEntryShare(
          associateId: asha.id,
          name: asha.name,
          isMe: false,
          amountPaise: 300000,
        ),
        SplitEntryShare(
          associateId: rahul.id,
          name: rahul.name,
          isMe: false,
          amountPaise: 300000,
        ),
      ],
    ),
  );
  await repository.saveSplitEntry(
    SplitEntryDraft(
      groupId: tripId,
      title: 'Airport cab',
      amountPaise: 180000,
      date: anchor.subtract(const Duration(days: 17)),
      payerAssociateId: asha.id,
      shares: [
        const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 60000),
        SplitEntryShare(
          associateId: asha.id,
          name: asha.name,
          isMe: false,
          amountPaise: 60000,
        ),
        SplitEntryShare(
          associateId: rahul.id,
          name: rahul.name,
          isMe: false,
          amountPaise: 60000,
        ),
      ],
    ),
  );

  final homeId = await repository.createSplitGroup(
    name: 'Flatmates',
    note: 'Shared home expenses',
    memberNames: const ['Meera', 'Vikram'],
  );
  final home = (await repository.splitGroups()).firstWhere(
    (group) => group.id == homeId,
  );
  await repository.saveSplitEntry(
    SplitEntryDraft(
      groupId: homeId,
      title: 'Monthly groceries',
      amountPaise: 240000,
      date: anchor.subtract(const Duration(days: 8)),
      payerAssociateId: null,
      shares: [
        const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 80000),
        for (final member in home.members)
          SplitEntryShare(
            associateId: member.id,
            name: member.name,
            isMe: false,
            amountPaise: 80000,
          ),
      ],
    ),
  );
}
