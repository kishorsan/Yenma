import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../domain/debt.dart';
import '../../domain/money.dart';
import 'debt_detail.dart';
import 'debt_form.dart';
import 'repayment_form.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  String _query = '';
  bool _showAllDebts = false;

  Future<void> _openDebt(DebtRecord debt) => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          DebtDetail(controller: widget.controller, debtId: debt.id),
    ),
  );

  Future<void> _recordRepayment(List<DebtRecord> debts) async {
    final available = debts
        .where(
          (debt) =>
              !debt.isSettled &&
              !calendarDate(debt.date).isAfter(calendarDate(DateTime.now())),
        )
        .toList();
    if (available.isEmpty) return;

    DebtRecord? selected;
    if (available.length == 1) {
      selected = available.single;
    } else {
      selected = await showModalBottomSheet<DebtRecord>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Choose a debt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...available.map(
                (debt) => ListTile(
                  leading: Icon(
                    debt.direction == DebtDirection.owedToMe
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                  ),
                  title: Text(debt.title),
                  subtitle: Text(debt.direction.label),
                  trailing: Text(formatMoney(debt.remainingPaise)),
                  onTap: () => Navigator.pop(context, debt),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (selected == null || !mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            RepaymentForm(controller: widget.controller, debt: selected!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final query = _query.trim().toLowerCase();
      final matchingDebts = controller.debts
          .where(
            (debt) =>
                query.isEmpty ||
                '${debt.person} ${debt.title}'.toLowerCase().contains(query),
          )
          .toList();
      final groups = <String, List<DebtRecord>>{};
      for (final debt in matchingDebts) {
        groups.putIfAbsent(debt.personKey, () => []).add(debt);
      }
      final people = groups.keys.toList()
        ..sort(
          (a, b) => groups[a]!.first.person.toLowerCase().compareTo(
            groups[b]!.first.person.toLowerCase(),
          ),
        );

      return RefreshIndicator(
        onRefresh: controller.loadDebts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Debts & repayments',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Track what each person owes you, what you owe them, and every repayment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (controller.receiptRecoveryError != null)
              Card(
                child: ListTile(
                  title: Text(controller.receiptRecoveryError!),
                  trailing: IconButton(
                    tooltip: 'Dismiss',
                    onPressed: controller.clearRecoveredReceipt,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            if (controller.recoveredReceipt != null)
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('Unsaved screenshot recovered'),
                      subtitle: Text('Add it to a new debt, or discard it.'),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => DebtForm(
                                controller: controller,
                                recoveredReceipt: controller.recoveredReceipt,
                              ),
                            ),
                          ),
                          child: const Text('Use screenshot'),
                        ),
                        TextButton(
                          onPressed: controller.clearRecoveredReceipt,
                          child: const Text('Discard'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (controller.debtError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(controller.debtError!),
                      TextButton(
                        onPressed: controller.loadDebts,
                        child: const Text('Retry debts'),
                      ),
                    ],
                  ),
                ),
              )
            else
              _OverallBalance(controller: controller),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search people or debts',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Card(
              child: CheckboxListTile(
                value: _showAllDebts,
                onChanged: (value) =>
                    setState(() => _showAllDebts = value ?? false),
                title: const Text('View all debts'),
                subtitle: const Text(
                  'Show every debt record beneath its person',
                ),
                secondary: const Icon(Icons.receipt_long_outlined),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Repayments by person',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${controller.debtRepayments.length} recorded',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (controller.debtsLoading)
              const LinearProgressIndicator()
            else if (controller.debtError == null && people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 48),
                    const SizedBox(height: 14),
                    Text(
                      query.isEmpty ? 'No debts yet' : 'No matching debts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      query.isEmpty
                          ? 'Add a debt to start tracking repayments by person.'
                          : 'Try another person or debt description.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (controller.debtError == null)
              ...people.map(
                (personKey) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PersonDebtCard(
                    debts: groups[personKey]!,
                    repayments: controller.debtRepayments
                        .where(
                          (payment) => groups[personKey]!.any(
                            (debt) => debt.id == payment.debtId,
                          ),
                        )
                        .toList(),
                    showDebts: _showAllDebts,
                    onOpenDebt: _openDebt,
                    onRecordRepayment: () =>
                        _recordRepayment(groups[personKey]!),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _OverallBalance extends StatelessWidget {
  const _OverallBalance({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primary,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _BalanceValue(
              label: 'Owed to you',
              amount: controller.outstanding(DebtDirection.owedToMe),
              icon: Icons.south_west_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 52,
            color: Theme.of(context).colorScheme.onPrimary
                .withValues(alpha: 0.25),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _BalanceValue(
              label: 'You owe',
              amount: controller.outstanding(DebtDirection.iOwe),
              icon: Icons.north_east_rounded,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BalanceValue extends StatelessWidget {
  const _BalanceValue({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final int amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: TextStyle(color: color)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          formatMoney(amount),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PersonDebtCard extends StatelessWidget {
  const _PersonDebtCard({
    required this.debts,
    required this.repayments,
    required this.showDebts,
    required this.onOpenDebt,
    required this.onRecordRepayment,
  });

  final List<DebtRecord> debts;
  final List<Repayment> repayments;
  final bool showDebts;
  final ValueChanged<DebtRecord> onOpenDebt;
  final VoidCallback onRecordRepayment;

  @override
  Widget build(BuildContext context) {
    final owed = debts
        .where((debt) => debt.direction == DebtDirection.owedToMe)
        .fold<int>(0, (sum, debt) => sum + debt.remainingPaise);
    final owing = debts
        .where((debt) => debt.direction == DebtDirection.iOwe)
        .fold<int>(0, (sum, debt) => sum + debt.remainingPaise);
    final canRepay = debts.any(
      (debt) =>
          !debt.isSettled &&
          !calendarDate(debt.date).isAfter(calendarDate(DateTime.now())),
    );
    final debtById = {for (final debt in debts) debt.id: debt};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    debts.first.person.characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debts.first.person,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${debts.length} debt ${debts.length == 1 ? 'record' : 'records'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (owed > 0)
                  _DirectionChip(
                    label: 'Owes you ${formatMoney(owed)}',
                    icon: Icons.south_west_rounded,
                  ),
                if (owing > 0)
                  _DirectionChip(
                    label: 'You owe ${formatMoney(owing)}',
                    icon: Icons.north_east_rounded,
                  ),
                if (owed == 0 && owing == 0)
                  const _DirectionChip(
                    label: 'All settled',
                    icon: Icons.check_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Repayments',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text('${repayments.length}'),
              ],
            ),
            const SizedBox(height: 8),
            if (repayments.isEmpty)
              Text(
                'No repayments recorded yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...repayments.map((payment) {
                final debt = debtById[payment.debtId]!;
                final verb = debt.direction == DebtDirection.owedToMe
                    ? 'Received'
                    : 'Paid';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    debt.direction == DebtDirection.owedToMe
                        ? Icons.call_received_rounded
                        : Icons.call_made_rounded,
                  ),
                  title: Text('$verb ${formatMoney(payment.amountPaise)}'),
                  subtitle: Text(
                    '${debt.title} · ${DateFormat.MMMd().format(payment.date)}'
                    '${payment.note.isEmpty ? '' : '\n${payment.note}'}',
                  ),
                  isThreeLine: payment.note.isNotEmpty,
                  onTap: () => onOpenDebt(debt),
                );
              }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canRepay ? onRecordRepayment : null,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Record repayment'),
              ),
            ),
            if (showDebts) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              Text(
                'All debts',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...debts.map(
                (debt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(debt.title),
                  subtitle: Text(
                    '${debt.direction.label} · ${DateFormat.MMMd().format(debt.date)}\n'
                    '${debt.isSettled ? 'Settled' : '${formatMoney(debt.remainingPaise)} remaining'}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenDebt(debt),
                ),
              ),
              if (owed > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy reminder'),
                    onPressed: () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                'Hi ${debts.first.person}, just a reminder that ${formatMoney(owed)} is still owed to me. Please pay me back when you can. Thanks!',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reminder copied.')),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not copy the reminder.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
    ),
  );
}
