import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/money_controller.dart';
import '../domain/money.dart';
import '../domain/monthly_plan.dart';

class MonthlyPlanScreen extends StatefulWidget {
  const MonthlyPlanScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<MonthlyPlanScreen> createState() => _MonthlyPlanScreenState();
}

class _MonthlyPlanScreenState extends State<MonthlyPlanScreen> {
  late DateTime _month;
  List<MoneyPlan> _plans = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await widget.controller.plansForMonth(_month);
      if (mounted) setState(() => _plans = plans);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load plans.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moveMonth(int offset) async {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    await _load();
  }

  Future<void> _openPlanForm([MoneyPlan? plan]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPlanScreen(
          controller: widget.controller,
          month: _month,
          plan: plan,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Plan page')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                _monthPicker(),
                const SizedBox(height: 18),
                Expanded(child: _content()),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _openPlanForm(),
                    child: const Text('Plan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _monthPicker() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton.filled(
        tooltip: 'Previous month',
        onPressed: _loading ? null : () => _moveMonth(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      const SizedBox(width: 10),
      Container(
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          DateFormat('MMM - yyyy').format(_month),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(width: 10),
      IconButton.outlined(
        tooltip: 'Next month',
        onPressed: _loading ? null : () => _moveMonth(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No plans for ${DateFormat.yMMMM().format(_month)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Add a plan without fitting it into a preset budget.'),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _plans.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openPlanForm(plan),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatMoney(plan.plannedPaise),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            ),
                            Text(
                              '${formatMoney(plan.remainingPaise)} remaining',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                        if (plan.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            plan.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RecordPlanScreen extends StatefulWidget {
  const RecordPlanScreen({
    super.key,
    required this.controller,
    required this.month,
    this.plan,
  });

  final MoneyController controller;
  final DateTime month;
  final MoneyPlan? plan;

  @override
  State<RecordPlanScreen> createState() => _RecordPlanScreenState();
}

class _RecordPlanScreenState extends State<RecordPlanScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _remainingAmount;
  late final TextEditingController _note;
  List<PlanType> _suggestions = const [];
  PlanType? _selectedType;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name = TextEditingController(text: plan?.planName ?? '');
    _amount = TextEditingController(
      text: plan == null ? '' : _amountText(plan.plannedPaise),
    );
    _remainingAmount = TextEditingController(
      text: plan == null ? '' : _amountText(plan.remainingPaise),
    );
    _note = TextEditingController(text: plan?.note ?? '');
    _loadSuggestions();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _remainingAmount.dispose();
    _note.dispose();
    super.dispose();
  }

  String _amountText(int paise) =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  int? _remainingPaise(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^0(?:\.0{1,2})?$').hasMatch(trimmed)) return 0;
    return parsePaise(trimmed);
  }

  Future<void> _loadSuggestions() async {
    try {
      final types = await widget.controller.planTypes();
      if (!mounted) return;
      _suggestions = types;
      if (widget.plan?.planTypeId != null) {
        _selectedType = types
            .where((type) => type.id == widget.plan!.planTypeId)
            .firstOrNull;
      }
    } catch (_) {
      if (mounted) _error = 'Existing plan suggestions are unavailable.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = parsePaise(_amount.text)!;
    final remaining = _remainingPaise(_remainingAmount.text)!;
    if (remaining > amount) {
      setState(() => _error = 'Remaining amount cannot exceed the amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.savePlan(
        MoneyPlan(
          id: widget.plan?.id,
          planTypeId: _selectedType?.id,
          planName: _name.text.trim(),
          month: widget.month,
          plannedPaise: amount,
          remainingPaise: remaining,
          note: _note.text,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this plan. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? 'Record Plan' : 'Edit Plan'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  DateFormat.yMMMM().format(widget.month),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 28),
                Autocomplete<PlanType>(
                  initialValue: TextEditingValue(text: _name.text),
                  displayStringForOption: (option) => option.name,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) return _suggestions;
                    return _suggestions.where(
                      (type) => type.name.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (type) {
                    _selectedType = type;
                    _name.text = type.name;
                  },
                  fieldViewBuilder:
                      (context, fieldController, focusNode, onSubmitted) {
                        fieldController.addListener(() {
                          if (_name.text != fieldController.text) {
                            _name.text = fieldController.text;
                            if (_selectedType?.name.toLowerCase() !=
                                fieldController.text.trim().toLowerCase()) {
                              _selectedType = null;
                            }
                          }
                        });
                        return TextFormField(
                          controller: fieldController,
                          focusNode: focusNode,
                          enabled: !_saving && !_loading,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Plan',
                            hintText: _loading
                                ? 'Loading suggestions…'
                                : 'e.g. Emergency fund',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter a plan name'
                              : null,
                        );
                      },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                  validator: (value) => parsePaise(value ?? '') == null
                      ? 'Enter a positive amount'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _remainingAmount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Remaining amount',
                    prefixText: '₹ ',
                  ),
                  validator: (value) => _remainingPaise(value ?? '') == null
                      ? 'Enter zero or a positive amount'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
