import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../domain/debt.dart';
import '../../domain/money.dart';
import 'receipt_editor.dart';

class DebtForm extends StatefulWidget {
  const DebtForm({
    super.key,
    required this.controller,
    this.debt,
    this.transaction,
    this.recoveredReceipt,
  });
  final MoneyController controller;
  final DebtRecord? debt;
  final MoneyTransaction? transaction;
  final Uint8List? recoveredReceipt;
  @override
  State<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<DebtForm> {
  final _form = GlobalKey<FormState>();
  late final _person = TextEditingController(text: widget.debt?.person);
  late final _title = TextEditingController(
    text: widget.debt?.title ?? widget.transaction?.title,
  );
  late final _amount = TextEditingController(
    text: widget.debt == null
        ? ''
        : '${widget.debt!.amountPaise ~/ 100}.${(widget.debt!.amountPaise % 100).toString().padLeft(2, '0')}',
  );
  late final _note = TextEditingController(text: widget.debt?.note);
  late DebtDirection _direction =
      widget.debt?.direction ?? DebtDirection.owedToMe;
  late DateTime _date =
      widget.debt?.date ??
      widget.transaction?.date ??
      calendarDate(DateTime.now());
  late Uint8List? _receipt = widget.recoveredReceipt;
  bool _removeReceipt = false;
  bool _saving = false;
  bool _picking = false;
  String? _error;
  int? get _transactionId =>
      widget.debt?.transactionId ?? widget.transaction?.id;
  @override
  void dispose() {
    _person.dispose();
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveDebt(
        DebtDraft(
          id: widget.debt?.id,
          transactionId: _transactionId,
          person: _person.text,
          title: _title.text,
          amountPaise: parsePaise(_amount.text)!,
          direction: _direction,
          date: _date,
          note: _note.text,
          receipt: _receipt,
          removeReceipt: _removeReceipt,
        ),
      );
      if (widget.recoveredReceipt != null) {
        widget.controller.clearRecoveredReceipt();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is DebtValidationException
              ? error.message
              : 'Could not save this debt. Your details are still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_picking,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.debt != null
              ? 'Edit debt'
              : _transactionId != null
              ? 'Add a friend’s share'
              : 'Add debt',
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
                if (_transactionId != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Linked to ${widget.transaction?.title ?? 'your original payment'}. ${widget.transaction == null ? '' : 'Paid: ${formatMoney(widget.transaction!.amountPaise)}.'} Enter only this person’s share.',
                      ),
                    ),
                  )
                else
                  const Text(
                    'Keep a record of money owed. This log does not add another income or expense.',
                  ),
                const SizedBox(height: 20),
                if (_transactionId == null && widget.debt == null) ...[
                  SegmentedButton<DebtDirection>(
                    segments: DebtDirection.values
                        .map(
                          (d) => ButtonSegment(value: d, label: Text(d.label)),
                        )
                        .toList(),
                    selected: {_direction},
                    onSelectionChanged: _saving
                        ? null
                        : (value) => setState(() => _direction = value.first),
                  ),
                  const SizedBox(height: 20),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _direction.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                TextFormField(
                  controller: _person,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    hintText: 'e.g. Arun',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the person’s name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'What was it for?',
                    hintText: 'e.g. Dinner after work',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Add a description'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _transactionId == null
                        ? 'Original amount owed'
                        : 'This friend’s share',
                    prefixText: '₹ ',
                    helperText: widget.debt != null
                        ? 'Edit the original share, not the remaining balance.'
                        : 'Enter up to 2 decimal places',
                  ),
                  validator: (value) => parsePaise(value ?? '') == null
                      ? 'Enter a positive amount'
                      : null,
                ),
                if (widget.transaction != null && widget.debt == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              final available =
                                  widget.transaction!.amountPaise -
                                  widget.controller
                                      .shares(widget.transaction!.id!)
                                      .fold(
                                        0,
                                        (sum, debt) => sum + debt.amountPaise,
                                      );
                              final half = available ~/ 2;
                              _amount.text =
                                  '${half ~/ 100}.${(half % 100).toString().padLeft(2, '0')}';
                            },
                      child: const Text('Half of the unallocated amount'),
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Debt date'),
                    subtitle: Text(DateFormat.yMMMMd().format(_date)),
                    onTap: _saving
                        ? null
                        : () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (value != null && mounted) {
                              setState(() => _date = value);
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
                    hintText: 'e.g. Pay me back whenever you can',
                  ),
                ),
                const SizedBox(height: 12),
                ReceiptEditor(
                  source: widget.controller.receipts,
                  bytes: _receipt,
                  hasSavedReceipt:
                      (widget.debt?.hasReceipt ?? false) && !_removeReceipt,
                  enabled: !_saving,
                  onBusyChanged: (value) => setState(() => _picking = value),
                  onChanged: (value) => setState(() {
                    _receipt = value;
                    _removeReceipt = value == null;
                  }),
                ),
                const SizedBox(height: 20),
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
                  icon: const Icon(Icons.check),
                  label: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_saving ? 'Saving…' : 'Save debt'),
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
