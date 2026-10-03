import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yenma/data/money_repository.dart';
import 'package:yenma/domain/money.dart';
import 'package:yenma/main-preview.dart' as preview;

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late SqliteMoneyRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yenma-preview-test-');
    repository = SqliteMoneyRepository(
      factory: databaseFactoryFfi,
      path: '${directory.path}${Platform.pathSeparator}preview.db',
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'preview seed creates one bank and fourteen days of transactions',
    () async {
      final today = DateTime(2026, 10, 3);

      await preview.seedPreviewData(repository, today: today);

      final september = await repository.transactions(DateTime(2026, 9));
      final october = await repository.transactions(DateTime(2026, 10));
      final transactions = [...september, ...october];
      expect(transactions, hasLength(8));
      expect(
        transactions.every(
          (transaction) =>
              transaction.bankName == 'HDFC Bank' &&
              transaction.source == 'SMS',
        ),
        isTrue,
      );
      expect(
        transactions.map((transaction) => calendarDate(transaction.date)),
        containsAll([today, today.subtract(const Duration(days: 14))]),
      );

      final banks = await repository.referenceData.banks();
      expect(banks, hasLength(1));
      expect(banks.single.name, 'HDFC Bank');
    },
  );

  test('preview seed is idempotent', () async {
    final today = DateTime(2026, 10, 3);

    await preview.seedPreviewData(repository, today: today);
    await preview.seedPreviewData(repository, today: today);

    final september = await repository.transactions(DateTime(2026, 9));
    final october = await repository.transactions(DateTime(2026, 10));
    expect([...september, ...october], hasLength(8));
    expect(await repository.referenceData.banks(), hasLength(1));
  });
}
