import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../domain/debt.dart';
import '../../domain/money.dart';
import 'debt_form.dart';
import 'debt_detail.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key, required this.controller});
  final MoneyController controller;
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  bool _settled = false;
  String _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final entries = controller.debts
          .where(
            (debt) =>
                debt.isSettled == _settled &&
                '${debt.person} ${debt.title}'.toLowerCase().contains(
                  _query.toLowerCase(),
                ),
          )
          .toList();
      final groups = <String, List<DebtRecord>>{};
      for (final debt in entries) {
        groups.putIfAbsent(debt.personKey, () => []).add(debt);
      }
      final people = groups.keys.toList()..sort();
      return RefreshIndicator(
        onRefresh: controller.loadDebts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Keep the split. Skip the awkward maths.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
                      subtitle: Text(
                        'The photo picker was interrupted. Add it to a new debt; your unsaved form details need to be entered again.',
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.push(
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
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 20,
                    children: [
                      _balance(
                        context,
                        'Owed to you',
                        controller.outstanding(DebtDirection.owedToMe),
                        Icons.south_west,
                      ),
                      _balance(
                        context,
                        'You owe',
                        controller.outstanding(DebtDirection.iOwe),
                        Icons.north_east,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Outstanding across all dates. Repayments reduce these balances.',
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search people or payments',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Outstanding')),
                ButtonSegment(value: true, label: Text('Settled')),
              ],
              selected: {_settled},
              onSelectionChanged: (value) =>
                  setState(() => _settled = value.first),
            ),
            const SizedBox(height: 20),
            if (controller.debtsLoading)
              const LinearProgressIndicator()
            else if (controller.debtError == null && entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 44),
                    const SizedBox(height: 16),
                    Text(
                      _query.isNotEmpty
                          ? 'No matching debts'
                          : _settled
                          ? 'Settled records will appear here'
                          : 'Nothing outstanding',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a debt here, or split an expense when you record a payment.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (controller.debtError == null)
              ...people.map((person) {
                final debts = groups[person]!;
                final owed = debts
                    .where((d) => d.direction == DebtDirection.owedToMe)
                    .fold(0, (sum, d) => sum + d.remainingPaise);
                final owing = debts
                    .where((d) => d.direction == DebtDirection.iOwe)
                    .fold(0, (sum, d) => sum + d.remainingPaise);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debts.first.person,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (!_settled)
                            Text(
                              [
                                if (owed > 0) 'Owes you ${formatMoney(owed)}',
                                if (owing > 0) 'You owe ${formatMoney(owing)}',
                              ].join(' · '),
                            ),
                          if (_query.isNotEmpty)
                            const Text('Totals reflect search results'),
                          if (!_settled && owed > 0)
                            TextButton.icon(
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Copy reminder'),
                              onPressed: () async {
                                final total = controller.debts
                                    .where(
                                      (debt) =>
                                          debt.personKey == person &&
                                          debt.direction ==
                                              DebtDirection.owedToMe,
                                    )
                                    .fold(
                                      0,
                                      (sum, debt) => sum + debt.remainingPaise,
                                    );
                                try {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          'Hi ${debts.first.person}, just a reminder that ${formatMoney(total)} is pending for the payments I covered. Please pay me back when you can. Thanks!',
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Reminder copied. You can share it when you’re ready.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not copy the reminder. Please retry.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          const Divider(),
                          ...debts.map(
                            (debt) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(debt.title),
                              subtitle: Text(
                                '${debt.direction.label} · ${DateFormat.MMMd().format(debt.date)}${debt.hasReceipt ? ' · Screenshot' : ''}\n${debt.isSettled ? 'Settled' : '${formatMoney(debt.remainingPaise)} remaining'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => DebtDetail(
                                    controller: controller,
                                    debtId: debt.id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
  Widget _balance(
    BuildContext context,
    String title,
    int amount,
    IconData icon,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(title)],
      ),
      const SizedBox(height: 8),
      Text(
        formatMoney(amount),
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ],
  );
}
