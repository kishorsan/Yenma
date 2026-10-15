// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'app/yenma_app.dart';
import 'data/money_repository.dart';
import 'preview_data/preview_data.dart';
import 'preview_data/preview_sms_sync_service.dart';

export 'preview_data/preview_data.dart' show seedPreviewData;

const _previewDatabaseName = 'yenma-preview-v3.db';

/// Starts the application with deterministic, non-production preview data.
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
