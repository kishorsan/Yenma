import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yenma/app/money_controller.dart';
import 'package:yenma/domain/money.dart';

import 'support/memory_repository.dart';

class DelayedRepository extends MemoryRepository {
  final pending = <int, Completer<List<MoneyTransaction>>>{};
  @override
  Future<List<MoneyTransaction>> transactions(DateTime month) =>
      (pending[month.month] = Completer<List<MoneyTransaction>>()).future;
}

void main() {
  test(
    'slow previous-month response cannot replace a newer selection',
    () async {
      final repository = DelayedRepository();
      final controller = MoneyController(repository);
      final first = controller.loadMonth(DateTime(2026, 1));
      final second = controller.loadMonth(DateTime(2026, 2));
      final february = MoneyTransaction(
        id: 2,
        title: 'February',
        amountPaise: 10,
        kind: TransactionKind.expense,
        categoryId: 1,
        date: DateTime(2026, 2),
      );
      repository.pending[2]!.complete([february]);
      await second;
      repository.pending[1]!.complete([]);
      await first;
      expect(controller.month, DateTime(2026, 2));
      expect(controller.transactions.single.title, 'February');
      expect(controller.loading, isFalse);
      controller.dispose();
    },
  );
}
