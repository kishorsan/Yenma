import '../data/money_repository.dart';
import '../domain/money.dart';
import 'debt_seed.dart';
import 'emi_seed.dart';
import 'loan_seed.dart';
import 'planning_seed.dart';
import 'reference_data_seed.dart';
import 'split_seed.dart';
import 'subscription_seed.dart';
import 'transaction_seed.dart';

const _previewSeedKey = 'preview_seed_version';
const _previewSeedVersion = '4';

/// Coordinates feature-specific fixtures for the isolated preview database.
///
/// Dates are derived from [today]. The version marker makes complete runs
/// idempotent while allowing a new fixture version to reseed a preview database.
Future<void> seedPreviewData(
  SqliteMoneyRepository repository, {
  DateTime? today,
}) async {
  final support = repository.applicationSupport;
  if (await support.setting(_previewSeedKey) == _previewSeedVersion) return;

  final anchor = calendarDate(today ?? DateTime.now());
  await seedReferencePreviewData(repository);
  await seedTransactionPreviewData(repository, anchor);
  await seedPlanningPreviewData(repository, anchor);
  await seedSubscriptionPreviewData(repository, anchor);
  await seedEmiPreviewData(repository, anchor);
  await seedLoanPreviewData(repository, anchor);
  await seedSplitPreviewData(repository, anchor);
  await seedDebtPreviewData(repository, anchor);
  await support.saveSetting(_previewSeedKey, _previewSeedVersion);
}
