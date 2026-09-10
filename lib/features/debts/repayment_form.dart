import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../domain/debt.dart';
import '../../domain/money.dart';

class RepaymentForm extends StatefulWidget {
  const RepaymentForm({
    super.key,
    required this.controller,
    required this.debt,
  });
  final MoneyController controller;
  final DebtRecord debt;
  @override
  State<RepaymentForm> createState() => _RepaymentFormState();
}

class _RepaymentFormState extends State<RepaymentForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = calendarDate(DateTime.now());
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
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
      await widget.controller.addRepayment(
        widget.debt.id,
        parsePaise(_amount.text)!,
        _date,
        _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is DebtValidationException
              ? error.message
              : 'Could not save the repayment. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Record repayment')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.debt.direction == DebtDirection.owedToMe
                      ? 'Received from ${widget.debt.person}'
                      : 'Paid to ${widget.debt.person}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Remaining: ${formatMoney(widget.debt.remainingPaise)}'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Repayment amount',
                    prefixText: '₹ ',
                  ),
                  validator: (value) {
                    final amount = parsePaise(value ?? '');
                    return amount == null || amount > widget.debt.remainingPaise
                        ? 'Enter an amount up to ${formatMoney(widget.debt.remainingPaise)}'
                        : null;
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                            final amount = widget.debt.remainingPaise;
                            _amount.text =
                                '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
                          },
                    child: const Text('Use full remaining amount'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Repayment date'),
                    subtitle: Text(DateFormat.yMMMMd().format(_date)),
                    leading: const Icon(Icons.calendar_today_outlined),
                    onTap: _saving
                        ? null
                        : () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: widget.debt.date,
                              lastDate: DateTime.now(),
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
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Repayment note (optional)',
                    hintText: 'e.g. UPI payment reference',
                  ),
                ),
                const Text(
                  'This updates the debt log only. It does not create another income or expense.',
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
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save repayment'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
