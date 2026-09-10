import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../app/money_controller.dart';
import '../domain/money.dart';
import '../domain/debt.dart';
import 'debts/receipt_editor.dart';
import 'debts/person_name_field.dart';

class TransactionForm extends StatefulWidget {
  const TransactionForm({
    super.key,
    required this.controller,
    this.transaction,
  });
  final MoneyController controller;
  final MoneyTransaction? transaction;
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.transaction?.title);
  late final _amount = TextEditingController(
    text: widget.transaction == null
        ? ''
        : '${widget.transaction!.amountPaise ~/ 100}.${(widget.transaction!.amountPaise % 100).toString().padLeft(2, '0')}',
  );
  late final _note = TextEditingController(text: widget.transaction?.note);
  late TransactionKind _kind =
      widget.transaction?.kind ?? TransactionKind.expense;
  late DateTime _date =
      widget.transaction?.date ?? calendarDate(DateTime.now());
  late int? _categoryId = widget.transaction?.categoryId;
  bool _saving = false;
  String? _error;
  final _friend = TextEditingController();
  final _share = TextEditingController();
  bool _split = false;
  bool _picking = false;
  Uint8List? _receipt;
  int get _allocated => widget.transaction?.id == null
      ? 0
      : widget.controller
            .shares(widget.transaction!.id!)
            .fold(0, (sum, debt) => sum + debt.amountPaise);
  int get _available => (parsePaise(_amount.text) ?? 0) - _allocated;
  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    _friend.dispose();
    _share.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final transaction = MoneyTransaction(
        id: widget.transaction?.id,
        title: _title.text,
        amountPaise: parsePaise(_amount.text)!,
        kind: _kind,
        categoryId: _categoryId!,
        date: _date,
        note: _note.text,
      );
      if (_split && _kind == TransactionKind.expense) {
        await widget.controller.saveSharedExpense(
          transaction,
          DebtDraft(
            person: _friend.text,
            title: _title.text,
            amountPaise: parsePaise(_share.text)!,
            direction: DebtDirection.owedToMe,
            date: _date,
            note: _note.text,
            receipt: _receipt,
          ),
        );
      } else {
        await widget.controller.save(transaction);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is DebtValidationException ? error.message : 'Could not save. Your details are still here; please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categories
        .where((category) => category.kinds.contains(_kind))
        .toList();
    return PopScope(
      canPop: !_saving && !_picking,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.transaction == null ? 'Add transaction' : 'Edit transaction',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'A little detail. A clearer picture.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TransactionKind>(
                    segments: TransactionKind.values
                        .map(
                          (kind) => ButtonSegment(
                            value: kind,
                            label: Text(kind.label),
                          ),
                        )
                        .toList(),
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _kind = value.first;
                            _split = false;
                            final eligible = widget.controller.categories
                                .where((c) => c.kinds.contains(_kind))
                                .toList();
                            _categoryId = eligible.length == 1
                                ? eligible.single.id
                                : null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      helperText: 'INR · up to 2 decimal places',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => parsePaise(value ?? '') == null
                        ? 'Enter a positive amount with up to 2 decimals'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _title,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Lunch with friends',
                    ),
                    maxLength: 120,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Give this transaction a title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('category-${_kind.name}'),
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    isExpanded: true,
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _categoryId = value),
                    validator: (value) =>
                        value == null ? 'Choose a category' : null,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Date'),
                      subtitle: Text(DateFormat.yMMMMd().format(_date)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving
                          ? null
                          : () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (selected != null && mounted) {
                                setState(() => _date = selected);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _note,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_kind == TransactionKind.expense) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Split with a friend'),
                      subtitle: const Text(
                        'I paid; someone owes me part of this payment.',
                      ),
                      value: _split,
                      onChanged: _saving || _picking
                          ? null
                          : (value) => setState(() => _split = value),
                    ),
                    if (_split) ...[
                      if (_allocated > 0)
                        Text(
                          'Existing shares: ${formatMoney(_allocated)} · Unallocated: ${formatMoney(_available)}',
                        ),
                      PersonNameField(
                        controller: _friend,
                        enabled: !_saving,
                        people: widget.controller.people,
                        label: 'Friend’s name',
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your friend’s name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _share,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Friend’s share',
                          prefixText: '₹ ',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final share = parsePaise(value ?? '');
                          final total = parsePaise(_amount.text);
                          return share == null ||
                                  total == null ||
                                  share > _available
                              ? 'Enter a share no larger than the unallocated amount'
                              : null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  final half =
                                      (_available > 0 ? _available : 0) ~/ 2;
                                  setState(
                                    () => _share.text =
                                        '${half ~/ 100}.${(half % 100).toString().padLeft(2, '0')}',
                                  );
                                },
                          child: Text(
                            _allocated == 0
                                ? 'Split equally'
                                : 'Half of the unallocated amount',
                          ),
                        ),
                      ),
                      if (parsePaise(_share.text) != null &&
                          parsePaise(_amount.text) != null &&
                          parsePaise(_share.text)! <= _available)
                        Text(
                          'Your share: ${formatMoney(_available - parsePaise(_share.text)!)} · Friend owes: ${formatMoney(parsePaise(_share.text)!)}',
                        ),
                      const SizedBox(height: 16),
                      ReceiptEditor(
                        source: widget.controller.receipts,
                        bytes: _receipt,
                        enabled: !_saving,
                        onChanged: (value) => setState(() => _receipt = value),
                        onBusyChanged: (value) =>
                            setState(() => _picking = value),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'The full payment stays in your spending. Your friend’s share is tracked separately in Debts. Add more friends from the payment details.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                  if (_kind == TransactionKind.transfer)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Transfers are recorded separately and excluded from income and spending totals.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _saving || _picking ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_saving ? 'Saving…' : 'Save transaction'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
