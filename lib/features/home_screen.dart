import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/money_controller.dart';
import '../app/theme.dart';
import '../domain/money.dart';
import 'transaction_form.dart';
import 'transaction_detail.dart';
import 'debts/debts_screen.dart';
import 'debts/debt_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final MoneyController controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  MoneyController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !controller.initializing &&
        controller.categories.isNotEmpty) {
      controller.loadMonth(controller.month);
      controller.loadDebts();
    }
  }

  void _add() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TransactionForm(controller: controller),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final ready =
          !controller.initializing && controller.categories.isNotEmpty;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: _tab == 3 ? kToolbarHeight : 48,
          titleTextStyle: _tab == 3
              ? Theme.of(context).textTheme.titleLarge
              : null,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(_tab == 3 ? 8 : 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'yenma',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  fontSize: _tab == 3 ? null : 19,
                ),
              ),
            ],
          ),
          actions: [
            if (_tab == 3)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  'MONEY, IN VIEW',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(letterSpacing: 1.2),
                ),
              ),
          ],
        ),
        body: controller.initializing
            ? const Center(child: CircularProgressIndicator())
            : !ready
            ? _failure(
                controller.error ?? 'Unable to open your data',
                controller.initialize,
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: _tab == 3
                      ? _settings()
                      : _tab == 2
                      ? DebtsScreen(controller: controller)
                      : _ledger(),
                ),
              ),
        floatingActionButton: ready && _tab != 3
            ? FloatingActionButton.extended(
                onPressed: _tab == 2
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => DebtForm(controller: controller),
                        ),
                      )
                    : _add,
                icon: const Icon(Icons.add),
                label: Text(_tab == 2 ? 'Add debt' : 'Add transaction'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake),
              label: 'Debts',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              label: 'Settings',
            ),
          ],
        ),
      );
    },
  );

  Widget _failure(String message, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _ledger() {
    final items = _tab == 0
        ? controller.transactions.take(5).toList()
        : controller.transactions;
    return RefreshIndicator(
      onRefresh: () => controller.loadMonth(controller.month),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tab == 0
                        ? 'Your money, a little clearer.'
                        : 'Your transactions',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _monthSelector(),
                  const SizedBox(height: 20),
                  if (!controller.loading && controller.error == null) ...[
                    _summary(),
                    const SizedBox(height: 24),
                    if (_tab == 0 &&
                        controller.summary.byCategory.isNotEmpty) ...[
                      _categoryBreakdown(),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _tab == 0
                                ? 'Recent activity'
                                : '${controller.transactions.length} transactions',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_tab == 0)
                          TextButton(
                            onPressed: () => setState(() => _tab = 1),
                            child: const Text('View all'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          if (controller.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (controller.error != null)
            SliverToBoxAdapter(
              child: _failure(
                controller.error!,
                () => controller.loadMonth(controller.month),
              ),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.savings_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'A fresh page for your money',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No transactions this month. Add one to start seeing your picture.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add),
                          label: const Text('Create your first entry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _transactionTile(items[index]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _monthSelector() => Card(
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed:
              controller.month.year == 1900 && controller.month.month == 1
              ? null
              : () => controller.loadMonth(
                  DateTime(controller.month.year, controller.month.month - 1),
                ),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => controller.loadMonth(DateTime.now()),
            child: Text(
              DateFormat.yMMMM().format(controller.month),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed:
              controller.month.year == 2100 && controller.month.month == 12
              ? null
              : () => controller.loadMonth(
                  DateTime(controller.month.year, controller.month.month + 1),
                ),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _summary() {
    final summary = controller.summary;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF153D32),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.north_east, color: mint, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'MONTHLY SPENDING',
                    style: TextStyle(
                      color: mint,
                      letterSpacing: 1.5,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(summary.expense),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${controller.transactions.length} entries  ·  Transfers excluded',
                style: const TextStyle(color: Color(0xFFBBD4CB)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _metric('Income', summary.income, TransactionKind.income),
              _metric(
                'Net cash flow',
                summary.net,
                summary.net < 0
                    ? TransactionKind.expense
                    : TransactionKind.income,
              ),
            ];
            return constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? Column(
                    children: [cards[0], const SizedBox(height: 12), cards[1]],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _metric(String label, int amount, TransactionKind kind) => Card(
    child: SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoney(amount),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: kindColor(kind, Theme.of(context).brightness),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _categoryBreakdown() {
    final summary = controller.summary;
    final entries = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where it went',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...entries.take(3).map((entry) {
              final category = controller.category(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(categoryIcon(category.icon), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(category.name)),
                        Text(formatMoney(entry.value)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: entry.value / summary.expense,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(MoneyTransaction transaction) {
    final category = controller.category(transaction.categoryId);
    final color = kindColor(transaction.kind, Theme.of(context).brightness);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetail(
              controller: controller,
              transaction: transaction,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(category.color).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  categoryIcon(category.icon),
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.name} · ${DateFormat.MMMd().format(transaction.date)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${transaction.kind.label} · ${formatMoney(transaction.amountPaise)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settings() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Make yourself at home.',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 24),
      Text('APPEARANCE', style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ThemeMode>(
                initialValue: controller.themeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('Follow system'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (mode) async {
                  if (mode == null) return;
                  try {
                    await controller.setTheme(mode);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Theme could not be saved. Please retry.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.currency_rupee),
              title: Text('Indian rupee'),
              subtitle: Text('All transactions are recorded in INR.'),
            ),
            ListTile(
              leading: Icon(Icons.phone_android_outlined),
              title: Text('Stored on this device'),
              subtitle: Text('Your entries stay local. No account needed.'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Text('Yenma · 0.2.2', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text('A quieter way to keep track of your money.'),
    ],
  );
}
