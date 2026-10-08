import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/domain/split.dart';

import 'support/memory_repository.dart';

void main() {
  sqfliteFfiInit();

  group('split persistence', () {
    late Directory directory;
    late SqliteMoneyRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('yenma_split_');
      repository = SqliteMoneyRepository(
        factory: databaseFactoryFfi,
        path: p.join(directory.path, 'money.db'),
      );
      await repository.initialize();
    });

    tearDown(() async {
      await repository.close();
      await directory.delete(recursive: true);
    });

    test(
      'payer direction creates only the user-relevant Debt records',
      () async {
        final groupId = await repository.createSplitGroup(
          name: 'Weekend',
          note: 'Shared costs',
          memberNames: const ['Asha', 'Ravi'],
        );
        final group = (await repository.splitGroups()).single;
        final asha = group.members.firstWhere(
          (member) => member.name == 'Asha',
        );
        final ravi = group.members.firstWhere(
          (member) => member.name == 'Ravi',
        );

        await repository.saveSplitEntry(
          SplitEntryDraft(
            groupId: groupId,
            title: 'Dinner',
            amountPaise: 9000,
            date: DateTime(2026, 10, 1),
            payerAssociateId: null,
            shares: [
              const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 3000),
              SplitEntryShare(
                associateId: asha.id,
                name: asha.name,
                isMe: false,
                amountPaise: 3000,
              ),
              SplitEntryShare(
                associateId: ravi.id,
                name: ravi.name,
                isMe: false,
                amountPaise: 3000,
              ),
            ],
          ),
        );
        await repository.saveSplitEntry(
          SplitEntryDraft(
            groupId: groupId,
            title: 'Taxi',
            amountPaise: 6000,
            date: DateTime(2026, 10, 2),
            payerAssociateId: asha.id,
            shares: [
              const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 3000),
              SplitEntryShare(
                associateId: asha.id,
                name: asha.name,
                isMe: false,
                amountPaise: 3000,
              ),
            ],
          ),
        );

        final entries = await repository.splitEntries(groupId);
        expect(entries.map((entry) => entry.title), ['Taxi', 'Dinner']);
        expect(entries.first.recordedForSomeoneElse, isTrue);
        expect(entries.last.recordedForSomeoneElse, isFalse);

        final debts = await repository.debts();
        expect(debts, hasLength(3));
        expect(
          debts.where((debt) => debt.direction == DebtDirection.owedToMe),
          hasLength(2),
        );
        final payable = debts.singleWhere(
          (debt) => debt.direction == DebtDirection.iOwe,
        );
        expect(payable.person, 'Asha');
        expect(payable.amountPaise, 3000);
      },
    );

    test('invalid totals are atomic', () async {
      final groupId = await repository.createSplitGroup(
        name: 'Home',
        note: '',
        memberNames: const ['Asha'],
      );
      final asha = (await repository.splitGroups()).single.members.single;
      await expectLater(
        repository.saveSplitEntry(
          SplitEntryDraft(
            groupId: groupId,
            title: 'Groceries',
            amountPaise: 10000,
            date: DateTime(2026, 10, 1),
            payerAssociateId: null,
            shares: [
              const SplitEntryShare(name: 'Me', isMe: true, amountPaise: 5000),
              SplitEntryShare(
                associateId: asha.id,
                name: asha.name,
                isMe: false,
                amountPaise: 4000,
              ),
            ],
          ),
        ),
        throwsA(isA<SplitValidationException>()),
      );
      expect(await repository.splitEntries(groupId), isEmpty);
      expect(await repository.debts(), isEmpty);
    });
  });

  testWidgets('Split shortcut opens the functional group flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryRepository();
    await tester.pumpWidget(
      YenmaApp(showWelcome: false, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    expect(find.text('Split together, remember once'), findsOneWidget);
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('split_group_name')), 'Goa');
    await tester.enterText(find.byKey(const Key('split_member_name')), 'Asha');
    await tester.tap(find.byTooltip('Add person'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create group'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No splits yet. Record the first shared expense and it will appear here like a conversation.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Record split'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('split_title')), 'Lunch');
    await tester.enterText(find.byKey(const Key('split_total')), '100');
    await tester.tap(find.text('Split equally'));
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Record split'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Record split'));
    await tester.pumpAndSettle();

    expect(find.text('Me paid'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Tracked in Debt'), findsOneWidget);
    final debts = await repository.debts();
    expect(debts.single.direction, DebtDirection.owedToMe);
    expect(debts.single.amountPaise, 5000);
  });
}
