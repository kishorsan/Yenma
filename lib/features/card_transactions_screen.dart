import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/money_controller.dart';
import '../app/theme.dart';
import '../domain/money.dart';
import 'transaction_detail.dart';

class CardTransactionsScreen extends StatefulWidget {
  const CardTransactionsScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<CardTransactionsScreen> createState() =>
      _CardTransactionsScreenState();
}

class _CardTransactionsScreenState extends State<CardTransactionsScreen> {
  String? _selectedBank;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final bankNames = controller.transactions
          .map((transaction) => transaction.bankName?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (_selectedBank != null && !bankNames.contains(_selectedBank)) {
        _selectedBank = null;
      }
      final recognizedTransactions = controller.transactions
          .where(
            (transaction) =>
                transaction.bankName != null &&
                transaction.bankName!.trim().isNotEmpty,
          )
          .toList();
      final transactions = _selectedBank == null
          ? recognizedTransactions
          : controller.transactions
                .where(
                  (transaction) =>
                      transaction.bankName?.trim() == _selectedBank,
                )
                .toList();
      final spending = transactions
          .where((transaction) => transaction.kind == TransactionKind.expense)
          .fold<int>(0, (total, transaction) => total + transaction.amountPaise);

      return RefreshIndicator(
        onRefresh: () => controller.loadMonth(controller.month),
        child: ListView(
          key: const PageStorageKey('card-transactions'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          children: [
            Text(
              'Card specific transactions',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a recognized bank or card to inspect its activity.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _monthSelector(context),
            const SizedBox(height: 16),
            if (bankNames.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All cards'),
                      selected: _selectedBank == null,
                      onSelected: (_) => setState(() => _selectedBank = null),
                    ),
                    for (final name in bankNames) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(name),
                        selected: _selectedBank == name,
                        onSelected: (_) => setState(() => _selectedBank = name),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedBank ?? 'All recognized cards',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('${transactions.length} transactions'),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(spending),
                      style: TextStyle(
                        color: context.yenmaColors.expense,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (controller.loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(controller.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => controller.loadMonth(controller.month),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (transactions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card_off_outlined, size: 42),
                      SizedBox(height: 12),
                      Text(
                        'No recognized card transactions this month.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...transactions.map((transaction) => _tile(transaction)),
          ],
        ),
      );
    },
  );

  Widget _monthSelector(BuildContext context) => Card(
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () => widget.controller.loadMonth(
            DateTime(
              widget.controller.month.year,
              widget.controller.month.month - 1,
            ),
          ),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => widget.controller.loadMonth(DateTime.now()),
            child: Text(DateFormat.yMMMM().format(widget.controller.month)),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: () => widget.controller.loadMonth(
            DateTime(
              widget.controller.month.year,
              widget.controller.month.month + 1,
            ),
          ),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _tile(MoneyTransaction transaction) {
    final category = widget.controller.category(transaction.categoryId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TransactionDetail(
                controller: widget.controller,
                transaction: transaction,
              ),
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Icon(categoryIcon(category.icon)),
          ),
          title: Text(transaction.title),
          subtitle: Text(
            '${category.name} · ${DateFormat.MMMd().format(transaction.date)}',
          ),
          trailing: Text(
            formatMoney(transaction.amountPaise),
            style: TextStyle(
              color: kindColor(transaction.kind, context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
