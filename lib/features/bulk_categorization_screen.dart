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
  TransactionKind? _selectedKind;
  int? _categoryId;
  bool _saving = false;
  String? _error;

  void _toggle(MoneyTransaction transaction, bool selected) {
    final matchingIds = transactionsMatchingName(
          widget.controller.transactions,
          transaction,
        )
        .map((candidate) => candidate.id!)
        .toSet();
    setState(() {
      if (selected) {
        _selectedKind ??= transaction.kind;
        _selectedIds.addAll(matchingIds);
      } else {
        _selectedIds.removeAll(matchingIds);
        if (_selectedIds.isEmpty) _selectedKind = null;
      }
      _categoryId = null;
      _error = null;
    });
  }

  Future<void> _apply() async {
    if (_categoryId == null || _selectedIds.isEmpty) return;
    final selected = widget.controller.transactions
        .where((transaction) => _selectedIds.contains(transaction.id))
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.bulkCategorize(selected, _categoryId!);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectedKind = null;
        _categoryId = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} transaction${selected.length == 1 ? '' : 's'} categorized',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not update the selected transactions. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final transactions = widget.controller.transactions;
      final categories = _selectedKind == null
          ? const <MoneyCategory>[]
          : widget.controller.categories
                .where((category) => category.kinds.contains(_selectedKind))
                .toList();
      final content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: transactions.isEmpty && !_saving
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'There are no transactions in this month to categorize.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _selectedIds.isEmpty
                                  ? 'Select a transaction. Matching names are selected together.'
                                  : '${_selectedIds.length} selected · ${_selectedKind!.label}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: transactions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              final selected = _selectedIds.contains(
                                transaction.id,
                              );
                              final enabled =
                                  !_saving &&
                                  (_selectedKind == null ||
                                      transaction.kind == _selectedKind);
                              final category = widget.controller.category(
                                transaction.categoryId,
                              );
                              return Card(
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: enabled
                                      ? (value) =>
                                            _toggle(transaction, value ?? false)
                                      : null,
                                  secondary: Icon(
                                    categoryIcon(category.icon),
                                    color: Color(category.color),
                                  ),
                                  title: Text(
                                    transaction.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${category.name} · ${DateFormat.MMMd().add_jm().format(transaction.date)}',
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                ),
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  key: ValueKey(_selectedKind),
                                  initialValue: _categoryId,
                                  decoration: const InputDecoration(
                                    labelText: 'New category',
                                  ),
                                  items: categories
                                      .map(
                                        (category) => DropdownMenuItem(
                                          value: category.id,
                                          child: Text(category.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _saving || _selectedIds.isEmpty
                                      ? null
                                      : (value) =>
                                            setState(() => _categoryId = value),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed:
                                        _saving ||
                                            _selectedIds.isEmpty ||
                                            _categoryId == null
                                        ? null
                                        : _apply,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.category_outlined),
                                    label: Text(
                                      _saving ? 'Applying…' : 'Apply category',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
      return PopScope(
        canPop: !_saving,
        child: widget.embedded
            ? content
            : Scaffold(
                appBar: AppBar(title: const Text('Categorize transactions')),
                body: content,
              ),
      );
    },
  );
}
