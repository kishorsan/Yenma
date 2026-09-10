import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/money_controller.dart';
import '../app/theme.dart';
import '../domain/money.dart';
import 'transaction_form.dart';
import '../domain/debt.dart';
import 'debts/debt_form.dart';
import 'debts/debt_detail.dart';

class TransactionDetail extends StatefulWidget {
  const TransactionDetail({
    super.key,
    required this.controller,
    required this.transaction,
  });
  final MoneyController controller;
  final MoneyTransaction transaction;
  @override
  State<TransactionDetail> createState() => _TransactionDetailState();
}

class _TransactionDetailState extends State<TransactionDetail> {
  bool _deleting = false;
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This entry will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.controller.delete(widget.transaction.id!);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is DebtValidationException
                  ? error.message
                  : 'Could not delete. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final category = widget.controller.category(transaction.categoryId);
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaction details')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                Icon(categoryIcon(category.icon), size: 48),
                const SizedBox(height: 20),
                Text(
                  transaction.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatMoney(transaction.amountPaise),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: kindColor(
                        transaction.kind,
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Type'),
                        subtitle: Text(transaction.kind.label),
                      ),
                      ListTile(
                        title: const Text('Category'),
                        subtitle: Text(category.name),
                      ),
                      ListTile(
                        title: const Text('Date'),
                        subtitle: Text(
                          DateFormat.yMMMMd().format(transaction.date),
                        ),
                      ),
                      const ListTile(
                        title: Text('Source'),
                        subtitle: Text('Manual entry · INR'),
                      ),
                      if (transaction.note.isNotEmpty)
                        ListTile(
                          title: const Text('Note'),
                          subtitle: Text(transaction.note),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (transaction.kind == TransactionKind.expense)
                  ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) {
                      final shares = widget.controller.shares(transaction.id!);
                      final allocated = shares.fold(
                        0,
                        (sum, debt) => sum + debt.amountPaise,
                      );
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment split',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (widget.controller.debtError != null) ...[
                                Text(widget.controller.debtError!),
                                TextButton(
                                  onPressed: widget.controller.loadDebts,
                                  child: const Text('Retry debts'),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                Text(
                                  'You paid: ${formatMoney(transaction.amountPaise)}',
                                ),
                                Text(
                                  'Your share / unallocated: ${formatMoney(transaction.amountPaise - allocated)}',
                                ),
                                ...shares.map(
                                  (debt) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(debt.person),
                                    subtitle: Text(
                                      '${formatMoney(debt.amountPaise)} share · ${debt.isSettled ? 'Settled' : '${formatMoney(debt.remainingPaise)} remaining'}',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => DebtDetail(
                                          controller: widget.controller,
                                          debtId: debt.id,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      _deleting ||
                                          widget.controller.debtsLoading ||
                                          allocated >= transaction.amountPaise
                                      ? null
                                      : () => Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DebtForm(
                                              controller: widget.controller,
                                              transaction: transaction,
                                            ),
                                          ),
                                        ),
                                  icon: const Icon(Icons.person_add_alt),
                                  label: const Text('Add a friend’s share'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _deleting
                      ? null
                      : () async {
                          final saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionForm(
                                controller: widget.controller,
                                transaction: transaction,
                              ),
                            ),
                          );
                          if (saved == true && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit transaction'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _deleting ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(_deleting ? 'Deleting…' : 'Delete transaction'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
