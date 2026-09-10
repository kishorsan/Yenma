import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../domain/debt.dart';
import '../../domain/money.dart';
import '../transaction_detail.dart';
import 'debt_form.dart';
import 'repayment_form.dart';

class DebtDetail extends StatefulWidget {
  const DebtDetail({super.key, required this.controller, required this.debtId});
  final MoneyController controller;
  final int debtId;
  @override
  State<DebtDetail> createState() => _DebtDetailState();
}

class _DebtDetailState extends State<DebtDetail> {
  late Future<List<Repayment>> _history = widget.controller.repository
      .repayments(widget.debtId);
  late Future<Uint8List?> _receipt = widget.controller.repository.debtReceipt(
    widget.debtId,
  );
  bool _busy = false;
  void _reload() => setState(() {
    _history = widget.controller.repository.repayments(widget.debtId);
    _receipt = widget.controller.repository.debtReceipt(widget.debtId);
  });
  Future<bool> _confirm(
    String title,
    String description,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _perform(
    Future<void> Function() action, {
    bool close = false,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (close) {
        Navigator.pop(context);
      } else {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is DebtValidationException
                  ? error.message
                  : 'Could not complete that action. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final debt = widget.controller.debt(widget.debtId);
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Debt details')),
          body: debt == null
              ? const Center(
                  child: Text('This debt record is no longer available.'),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          debt.person,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          debt.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  debt.isSettled
                                      ? 'Settled'
                                      : debt.direction == DebtDirection.owedToMe
                                      ? 'Still owed to you'
                                      : 'You still owe',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  formatMoney(debt.remainingPaise),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Original share: ${formatMoney(debt.amountPaise)}',
                                ),
                                Text(
                                  'Repaid: ${formatMoney(debt.repaidPaise)}',
                                ),
                                const SizedBox(height: 8),
                                Text(DateFormat.yMMMMd().format(debt.date)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.controller.debtError != null)
                          Card(
                            child: ListTile(
                              title: Text(widget.controller.debtError!),
                              trailing: TextButton(
                                onPressed: widget.controller.loadDebts,
                                child: const Text('Retry'),
                              ),
                            ),
                          ),
                        if (debt.note.isNotEmpty)
                          Card(
                            child: ListTile(
                              title: const Text('Note'),
                              subtitle: Text(debt.note),
                            ),
                          ),
                        if (debt.transactionId != null)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: const Text('Linked payment'),
                              subtitle: const Text(
                                'View the original expense and all its shares',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _busy
                                  ? null
                                  : () => _perform(() async {
                                      final transaction = await widget
                                          .controller
                                          .repository
                                          .transactionById(debt.transactionId!);
                                      if (transaction == null) {
                                        throw const DebtValidationException(
                                          'The original payment is unavailable.',
                                        );
                                      }
                                      if (!context.mounted) return;
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => TransactionDetail(
                                            controller: widget.controller,
                                            transaction: transaction,
                                          ),
                                        ),
                                      );
                                    }),
                            ),
                          ),
                        if (debt.hasReceipt)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: FutureBuilder<Uint8List?>(
                              future: _receipt,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError ||
                                    snapshot.data == null) {
                                  return ListTile(
                                    title: const Text(
                                      'Screenshot could not be loaded',
                                    ),
                                    trailing: TextButton(
                                      onPressed: _reload,
                                      child: const Text('Retry'),
                                    ),
                                  );
                                }
                                final bytes = snapshot.data!;
                                return Card(
                                  child: Column(
                                    children: [
                                      const ListTile(
                                        leading: Icon(Icons.image_outlined),
                                        title: Text('Receipt / UPI screenshot'),
                                        subtitle: Text('Tap to zoom'),
                                      ),
                                      InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => Scaffold(
                                              appBar: AppBar(
                                                title: const Text('Attachment'),
                                              ),
                                              body: Center(
                                                child: InteractiveViewer(
                                                  maxScale: 6,
                                                  child: Image.memory(
                                                    bytes,
                                                    errorBuilder: (_, _, _) =>
                                                        const Text(
                                                          'This image could not be displayed.',
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Image.memory(
                                            bytes,
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                            cacheWidth: 600,
                                            errorBuilder: (_, _, _) =>
                                                const Text(
                                                  'Preview unavailable. Replace this image using Edit debt.',
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (!debt.isSettled)
                          FilledButton.icon(
                            onPressed:
                                _busy ||
                                    widget.controller.debtError != null ||
                                    debt.date.isAfter(
                                      calendarDate(DateTime.now()),
                                    )
                                ? null
                                : () async {
                                    final saved = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RepaymentForm(
                                          controller: widget.controller,
                                          debt: debt,
                                        ),
                                      ),
                                    );
                                    if (saved == true && mounted) _reload();
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Record repayment'),
                          ),
                        if (debt.date.isAfter(calendarDate(DateTime.now())))
                          const Text(
                            'Repayments can be recorded on or after the debt date.',
                          ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _perform(() async {
                                  final transaction = debt.transactionId == null
                                      ? null
                                      : await widget.controller.repository
                                            .transactionById(
                                              debt.transactionId!,
                                            );
                                  if (!context.mounted) return;
                                  await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DebtForm(
                                        controller: widget.controller,
                                        debt: debt,
                                        transaction: transaction,
                                      ),
                                    ),
                                  );
                                }),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit debt'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Repayment history',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Repayment>>(
                          future: _history,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return ListTile(
                                title: const Text(
                                  'History could not be loaded',
                                ),
                                trailing: TextButton(
                                  onPressed: _reload,
                                  child: const Text('Retry'),
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const LinearProgressIndicator();
                            }
                            if (snapshot.data!.isEmpty) {
                              return const Text('No repayments recorded yet.');
                            }
                            return Column(
                              children: snapshot.data!
                                  .map(
                                    (payment) => Card(
                                      child: ListTile(
                                        title: Text(
                                          formatMoney(payment.amountPaise),
                                        ),
                                        subtitle: Text(
                                          '${DateFormat.yMMMd().format(payment.date)}${payment.note.isEmpty ? '' : '\n${payment.note}'}',
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Remove repayment',
                                          onPressed: _busy
                                              ? null
                                              : () async {
                                                  if (await _confirm(
                                                        'Remove repayment?',
                                                        'This restores ${formatMoney(payment.amountPaise)} to the outstanding balance. No bank transfer is made.',
                                                        'Remove',
                                                      ) &&
                                                      mounted) {
                                                    await _perform(
                                                      () => widget.controller
                                                          .deleteRepayment(
                                                            payment.id,
                                                          ),
                                                    );
                                                  }
                                                },
                                          icon: const Icon(Icons.undo),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                        'Delete debt record?',
                                        'This deletes this debt, its screenshot and repayment history. The original payment is kept. This does not mean the debt was paid.',
                                        'Delete debt',
                                      ) &&
                                      mounted) {
                                    await _perform(
                                      () =>
                                          widget.controller.deleteDebt(debt.id),
                                      close: true,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete debt record'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
