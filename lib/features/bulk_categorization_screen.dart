import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/money_controller.dart';
import '../app/theme.dart';
import '../domain/money.dart';

class BulkCategorizationScreen extends StatefulWidget {
  const BulkCategorizationScreen({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final MoneyController controller;
  final bool embedded;

  @override
  State<BulkCategorizationScreen> createState() =>
      _BulkCategorizationScreenState();
}

class _BulkCategorizationScreenState extends State<BulkCategorizationScreen> {
  final Set<int> _selectedIds = {};
  List<MoneyTransaction> _transactions = const [];
  TransactionKind? _selectedKind;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _loadGeneration = 0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _rangeStart => DateTime(_today.year, _today.month - 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _rangeStart;
      final today = _today;
      final tomorrow = today.add(const Duration(days: 1));
      final transactions = await widget.controller.repository
          .transactionsBetween(start, tomorrow);
      transactions.sort((a, b) {
        final date = b.date.compareTo(a.date);
        if (date != 0) return date;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Transactions could not be loaded. Please retry.';
      });
    }
  }

  void _toggle(MoneyTransaction transaction) {
    final id = transaction.id;
    if (id == null || _saving) return;
    setState(() {
      if (_selectedIds.remove(id)) {
        if (_selectedIds.isEmpty) _selectedKind = null;
      } else {
        if (_selectedKind != null && _selectedKind != transaction.kind) return;
        _selectedKind ??= transaction.kind;
        _selectedIds.add(id);
      }
      _error = null;
    });
  }

  Future<void> _openCategorySheet() async {
    if (_selectedIds.isEmpty || _selectedKind == null || _saving) return;
    final categories = widget.controller.categories
        .where((category) => category.kinds.contains(_selectedKind))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.58,
        child: _CategorySheet(
          count: _selectedIds.length,
          categories: categories,
          onSelected: (category) {
            Navigator.of(sheetContext).pop();
            _apply(category.id);
          },
        ),
      ),
    );
  }

  Future<void> _apply(int categoryId) async {
    final selected = _transactions
        .where((transaction) => _selectedIds.contains(transaction.id))
        .toList();
    if (selected.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.bulkCategorize(selected, categoryId);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectedKind = null;
        _saving = false;
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} transaction${selected.length == 1 ? '' : 's'} categorized',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update the selection. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Positioned.fill(child: _body()),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: _selectedIds.isEmpty ? const Offset(0, 2) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _selectedIds.isEmpty ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _selectedIds.isEmpty,
                  child: FilledButton.icon(
                    key: const ValueKey('categorize-selection'),
                    onPressed: _saving ? null : _openCategorySheet,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(190, 52),
                      shape: const StadiumBorder(),
                      elevation: 4,
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.category_outlined),
                    label: Text(
                      _saving
                          ? 'Categorizing…'
                          : 'Categorize ${_selectedIds.length}',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: !_saving,
      child: widget.embedded
          ? content
          : Scaffold(
              appBar: AppBar(title: const Text('Categorize')),
              body: content,
            ),
    );
  }

  Widget _body() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      key: const PageStorageKey('bulk-categorization'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
      children: [
        Text(
          'Categorize',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'From ${DateFormat.MMMd().format(_rangeStart)} through today · newest first',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        if (_selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedIds.length} selected · ${_selectedKind!.label}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _selectedIds.clear();
                          _selectedKind = null;
                        }),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        if (_error != null) _errorCard(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_transactions.isEmpty)
          _emptyCard()
        else
          for (final transaction in _transactions)
            _transactionTile(transaction),
      ],
    ),
  );

  Widget _transactionTile(MoneyTransaction transaction) {
    final selected = _selectedIds.contains(transaction.id);
    final enabled =
        !_saving &&
        (_selectedKind == null ||
            transaction.kind == _selectedKind ||
            selected);
    final category = widget.controller.category(transaction.categoryId);
    final categoryColor = Color(category.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.42,
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => _toggle(transaction) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: categoryColor.withValues(alpha: 0.16),
                    foregroundColor: categoryColor,
                    child: Icon(categoryIcon(category.icon), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${category.name} · ${DateFormat.MMMd().format(transaction.date)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(transaction.amountPaise),
                        style: TextStyle(
                          color: kindColor(transaction.kind, context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            'No recent transactions to categorize.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _errorCard() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_error!)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({
    required this.count,
    required this.categories,
    required this.onSelected,
  });

  final int count;
  final List<MoneyCategory> categories;
  final ValueChanged<MoneyCategory> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a category',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Apply to $count transaction${count == 1 ? '' : 's'} · Drag down to pause',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              final color = Color(category.color);
              return Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('category-${category.id}'),
                  onTap: () => onSelected(category),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.16),
                          foregroundColor: color,
                          child: Icon(categoryIcon(category.icon)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
