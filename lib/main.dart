import 'package:flutter/material.dart';

import 'app/yenma_app.dart';
import 'data/money_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(YenmaApp(repository: SqliteMoneyRepository()));
}
