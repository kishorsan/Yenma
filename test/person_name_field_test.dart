import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/yenma_app.dart';
import 'package:yenma/domain/debt.dart';
import 'package:yenma/features/debts/person_name_field.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets(
    'blank field offers saved people and typing filters without restricting new names',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: PersonNameField(
                controller: controller,
                people: const ['Arun Kumar', 'Meera'],
                label: 'Person',
                validator: (_) => null,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(find.text('Saved people'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Meera'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  ARUN  ');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Arun Kumar'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Meera'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Arun Kumar'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Arun Kumar');
      expect(find.text('Saved people'), findsNothing);
      await tester.tap(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'New friend');
      await tester.pumpAndSettle();
      expect(controller.text, 'New friend');
      expect(find.byKey(const ValueKey('person-suggestions')), findsNothing);
      await tester.tap(find.byTooltip('Show saved people'));
      await tester.pumpAndSettle();
      expect(
        controller.text,
        'New friend',
      ); // Browsing must not erase typed text.
      await tester.tap(find.widgetWithText(ListTile, 'Meera'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Meera');
    },
  );

  testWidgets(
    'existing people are selectable in both new debt and expense split forms',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = MemoryRepository();
      await repository.saveDebt(
        DebtDraft(
          person: 'Arun',
          title: 'Earlier meal',
          amountPaise: 100,
          direction: DebtDirection.owedToMe,
          date: DateTime.now(),
        ),
      );
      await tester.pumpWidget(
        YenmaApp(repository: repository, showWelcome: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Debts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add debt'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PersonNameField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Arun'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PersonNameField>(find.byType(PersonNameField))
            .controller
            .text,
        'Arun',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add transaction'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Split with a friend'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Split with a friend'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PersonNameField));
      await tester.tap(find.byType(PersonNameField));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Arun'));
      await tester.tap(find.widgetWithText(ListTile, 'Arun'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PersonNameField>(find.byType(PersonNameField))
            .controller
            .text,
        'Arun',
      );
    },
  );
}
