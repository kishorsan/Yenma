// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'app/yenma_app.dart';
import 'data/money_repository.dart';
import 'data/reference_data.dart';
import 'data/sms_sync.dart';
import 'domain/money.dart';

const _previewDatabaseName = 'yenma-preview.db';
const _previewSeedKey = 'preview_seed_version';
const _previewSeedVersion = '1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databasePath = path.join(
    await getDatabasesPath(),
    _previewDatabaseName,
  );
  const resetPreview = bool.fromEnvironment('RESET_PREVIEW');
  if (resetPreview) await deleteDatabase(databasePath);

  final repository = SqliteMoneyRepository(path: databasePath);
  await repository.initialize();
  await seedPreviewData(repository);

  runApp(
    YenmaApp(
      repository: repository,
      sms: PreviewSmsSyncService(),
      showWelcome: false,
    ),
  );
}

/// Adds deterministic sample content to the isolated preview database.
///
/// Dates are calculated from [today] so the fixtures always cover the latest
/// two weeks. A version marker makes this idempotent and preserves edits made
/// while testing the preview app.
Future<void> seedPreviewData(
  SqliteMoneyRepository repository, {
  DateTime? today,
}) async {
  final support = repository.applicationSupport;
  if (await support.setting(_previewSeedKey) == _previewSeedVersion) return;

  final anchor = calendarDate(today ?? DateTime.now());
  await repository.referenceData.saveBank(
    const BankRecord(name: 'HDFC Bank', code: 'HDFC'),
  );
  await repository.importTransactions([
    _previewTransaction(
      title: 'Amazon India',
      amountPaise: 249900,
      categoryId: 4,
      date: anchor,
      sequence: 0,
    ),
    _previewTransaction(
      title: 'Cafe Coffee Day',
      amountPaise: 46000,
      categoryId: 1,
      date: anchor.subtract(const Duration(days: 2)),
      sequence: 1,
    ),
    _previewTransaction(
      title: 'Apollo Pharmacy',
      amountPaise: 87500,
      categoryId: 5,
      date: anchor.subtract(const Duration(days: 4)),
      sequence: 2,
    ),
    _previewTransaction(
      title: 'Netflix',
      amountPaise: 64900,
      categoryId: 8,
      date: anchor.subtract(const Duration(days: 6)),
      sequence: 3,
    ),
    _previewTransaction(
      title: 'Indian Oil',
      amountPaise: 240000,
      categoryId: 3,
      date: anchor.subtract(const Duration(days: 8)),
      sequence: 4,
    ),
    _previewTransaction(
      title: 'Fresh Basket',
      amountPaise: 184000,
      categoryId: 2,
      date: anchor.subtract(const Duration(days: 10)),
      sequence: 5,
    ),
    _previewTransaction(
      title: 'House Rent',
      amountPaise: 1200000,
      categoryId: 14,
      date: anchor.subtract(const Duration(days: 12)),
      sequence: 6,
    ),
    _previewTransaction(
      title: 'Monthly Salary',
      amountPaise: 4800000,
      categoryId: 10,
      kind: TransactionKind.income,
      date: anchor.subtract(const Duration(days: 14)),
      sequence: 7,
    ),
  ]);
  await support.saveSetting(_previewSeedKey, _previewSeedVersion);
}

MoneyTransaction _previewTransaction({
  required String title,
  required int amountPaise,
  required int categoryId,
  required DateTime date,
  required int sequence,
  TransactionKind kind = TransactionKind.expense,
}) => MoneyTransaction(
  title: title,
  amountPaise: amountPaise,
  kind: kind,
  categoryId: categoryId,
  date: DateTime(date.year, date.month, date.day, 12),
  source: 'SMS',
  bankName: 'HDFC Bank',
  externalId: 'preview-hdfc-${dateKey(date)}-$sequence',
  recipientKey: transactionNameKey(title),
  note: 'Preview fixture',
);

/// Prevents preview runs from reading or scheduling access to real SMS data.
class PreviewSmsSyncService extends SmsSyncService {
  @override
  Future<List<BankSms>> read({DateTime? from, DateTime? until}) async =>
      const [];

  @override
  Future<void> scheduleDaily() async {}
}
