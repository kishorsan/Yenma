import 'package:flutter/material.dart';

import '../data/money_repository.dart';
import '../data/receipt_source.dart';
import '../features/home_screen.dart';
import 'money_controller.dart';
import 'theme.dart';

class YenmaApp extends StatefulWidget {
  const YenmaApp({super.key, required this.repository, this.receipts});
  final MoneyRepository repository;
  final ReceiptSource? receipts;
  @override
  State<YenmaApp> createState() => _YenmaAppState();
}

class _YenmaAppState extends State<YenmaApp> {
  late final controller = MoneyController(
    widget.repository,
    receipts: widget.receipts,
  );
  @override
  void initState() {
    super.initState();
    controller.initialize();
    controller.recoverReceipt();
  }

  @override
  void dispose() {
    controller.dispose();
    widget.repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'Yenma',
      debugShowCheckedModeBanner: false,
      theme: yenmaTheme(Brightness.light),
      darkTheme: yenmaTheme(Brightness.dark),
      themeMode: controller.themeMode,
      home: HomeScreen(controller: controller),
    ),
  );
}
