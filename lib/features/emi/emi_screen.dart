import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../data/commitments_data.dart';
import '../../domain/money.dart';

class EmiScreen extends StatefulWidget {
  const EmiScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<EmiScreen> createState() => _EmiScreenState();
}

class _EmiScreenState extends State<EmiScreen> {
  List<EmiRecord> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await widget.controller.emis();
      if (mounted) setState(() => _records = values);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load EMIs.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _record([EmiRecord? emi]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordEmiScreen(controller: widget.controller, emi: emi),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _open(EmiRecord emi) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmiDetailScreen(controller: widget.controller, emi: emi),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EMI')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _record(),
      icon: const Icon(Icons.add),
      label: const Text('Record EMI'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _body(),
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_repeat_outlined, size: 54),
              const SizedBox(height: 18),
              Text(
                'No EMIs yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your own EMI or one that is being paid through you.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _record(),
                child: const Text('Record EMI'),
              ),
            ],
          ),
        ),
      );
    }
    final active = _records.where((item) => !item.isComplete).toList();
    final complete = _records.where((item) => item.isComplete).toList();
    final remaining = active.fold<int>(
      0,
      (sum, item) => sum + item.remainingPaise,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL REMAINING',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(remaining),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${active.length} active · ${complete.length} completed',
                  ),
                ],
              ),
            ),
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('Active'),
            const SizedBox(height: 10),
            ...active.map(_card),
          ],
          if (complete.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('Completed'),
            const SizedBox(height: 10),
            ...complete.map(_card),
          ],
        ],
      ),
    );
  }

  Widget _heading(String value) => Text(
    value,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _card(EmiRecord emi) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        onTap: () => _open(emi),
        leading: CircleAvatar(
          child: Icon(
            emi.ownership == EmiOwnership.mine
                ? Icons.account_balance_outlined
                : Icons.swap_horiz,
          ),
        ),
        title: Text(
          emi.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          emi.isComplete
              ? 'Completed'
              : '${formatMoney(emi.remainingPaise)} remaining · due day ${emi.billingDay}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );
}

class EmiDetailScreen extends StatefulWidget {
  const EmiDetailScreen({
    super.key,
    required this.controller,
    required this.emi,
  });

  final MoneyController controller;
  final EmiRecord emi;

  @override
  State<EmiDetailScreen> createState() => _EmiDetailScreenState();
}

class _EmiDetailScreenState extends State<EmiDetailScreen> {
  late EmiRecord _emi = widget.emi;
  List<EmiInstallment> _installments = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.controller.emis();
    final payments = await widget.controller.emiInstallments(_emi.id!);
    if (!mounted) return;
    setState(() {
      _emi = all.firstWhere((item) => item.id == _emi.id);
      _installments = payments;
      _loading = false;
    });
  }

  Future<void> _recordPayment() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordEmiInstallmentScreen(
          controller: widget.controller,
          emi: _emi,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordEmiScreen(controller: widget.controller, emi: _emi),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_emi.name),
      actions: [
        IconButton(
          onPressed: _edit,
          tooltip: 'Edit EMI',
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    floatingActionButton: _emi.isComplete
        ? null
        : FloatingActionButton.extended(
            onPressed: _recordPayment,
            icon: const Icon(Icons.add),
            label: const Text('Record monthly EMI'),
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _emi.isComplete ? 'COMPLETED' : 'REMAINING',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatMoney(_emi.remainingPaise),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Divider(height: 32),
                          _fact(
                            'Original principal',
                            formatMoney(_emi.principalPaise),
                          ),
                          _fact(
                            'Processing fee',
                            formatMoney(_emi.processingFeePaise),
                          ),
                          _fact(
                            'EMI date',
                            'Day ${_emi.billingDay} of each month',
                          ),
                          _fact(
                            'Type',
                            _emi.ownership == EmiOwnership.mine
                                ? 'My EMI'
                                : 'Paid through me',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Monthly EMIs',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_installments.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No monthly EMIs recorded yet.'),
                      ),
                    )
                  else
                    ..._installments.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            leading: Icon(
                              item.isPaid
                                  ? Icons.check_circle_outline
                                  : Icons.schedule_outlined,
                            ),
                            title: Text(
                              formatMoney(item.totalPaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat.yMMMd().format(item.date)} · Principal ${formatMoney(item.principalPaise)}\n'
                              'Interest ${formatMoney(item.interestPaise)} · GST ${formatMoney(item.gstPaise)}',
                            ),
                            isThreeLine: true,
                            trailing: Text(item.isPaid ? 'Paid' : 'Due'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class RecordEmiScreen extends StatefulWidget {
  const RecordEmiScreen({super.key, required this.controller, this.emi});

  final MoneyController controller;
  final EmiRecord? emi;

  @override
  State<RecordEmiScreen> createState() => _RecordEmiScreenState();
}

class _RecordEmiScreenState extends State<RecordEmiScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _principal;
  late final TextEditingController _fee;
  late final TextEditingController _note;
  late DateTime _start;
  DateTime? _end;
  late int _billingDay;
  late EmiOwnership _ownership;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final emi = widget.emi;
    final today = DateTime.now();
    _name = TextEditingController(text: emi?.name ?? '');
    _principal = TextEditingController(
      text: emi == null ? '' : _amountText(emi.principalPaise),
    );
    _fee = TextEditingController(
      text: emi == null ? '0' : _amountText(emi.processingFeePaise),
    );
    _note = TextEditingController(text: emi?.note ?? '');
    _start =
        emi?.startDate ??
        DateTime(today.year, today.month, today.day.clamp(1, 28));
    _end = emi?.endDate;
    _billingDay = emi?.billingDay ?? today.day.clamp(1, 28);
    _ownership = emi?.ownership ?? EmiOwnership.mine;
  }

  @override
  void dispose() {
    _name.dispose();
    _principal.dispose();
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _choose(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    selectableDayPredicate: (date) => date.day <= 28,
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveEmi(
        EmiRecord(
          id: widget.emi?.id,
          name: _name.text.trim(),
          principalPaise: parsePaise(_principal.text)!,
          paidPrincipalPaise: widget.emi?.paidPrincipalPaise ?? 0,
          processingFeePaise: _parseNonNegativePaise(_fee.text)!,
          billingDay: _billingDay,
          startDate: _start,
          endDate: _end,
          note: _note.text.trim(),
          ownership: _ownership,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this EMI. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.emi == null ? 'Record EMI' : 'Edit EMI')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<EmiOwnership>(
                initialValue: _ownership,
                decoration: const InputDecoration(labelText: 'EMI type'),
                items: const [
                  DropdownMenuItem(
                    value: EmiOwnership.mine,
                    child: Text('My EMI'),
                  ),
                  DropdownMenuItem(
                    value: EmiOwnership.throughMe,
                    child: Text('Paid through me'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _ownership = value!),
              ),
              const SizedBox(height: 8),
              Text(
                _ownership == EmiOwnership.mine
                    ? 'You are responsible for this EMI.'
                    : 'Someone pays you, and you make the monthly EMI payment.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'EMI name'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter an EMI name' : null,
              ),
              const SizedBox(height: 18),
              _amountField(_principal, 'Principal amount', positive: true),
              const SizedBox(height: 18),
              _amountField(_fee, 'One-time processing fee'),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: _billingDay,
                decoration: const InputDecoration(
                  labelText: 'Monthly EMI date',
                ),
                items: List.generate(
                  28,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('Day ${index + 1}'),
                  ),
                ),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _billingDay = value!),
              ),
              const SizedBox(height: 18),
              _dateField('Start date', _start, () async {
                final value = await _choose(_start);
                if (value != null) setState(() => _start = value);
              }),
              const SizedBox(height: 18),
              _dateField(
                'End date (optional)',
                _end,
                () async {
                  final value = await _choose(_end ?? _start);
                  if (value != null) setState(() => _end = value);
                },
                clear: _end == null ? null : () => setState(() => _end = null),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _note,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _amountField(
    TextEditingController controller,
    String label, {
    bool positive = false,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, prefixText: '₹ '),
    validator: (value) {
      final amount = positive
          ? parsePaise(value ?? '')
          : _parseNonNegativePaise(value ?? '');
      return amount == null
          ? (positive
                ? 'Enter a positive amount'
                : 'Enter zero or a positive amount')
          : null;
    },
  );

  Widget _dateField(
    String label,
    DateTime? value,
    VoidCallback open, {
    VoidCallback? clear,
  }) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: _saving ? null : open,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: clear == null
            ? const Icon(Icons.calendar_today_outlined)
            : IconButton(onPressed: clear, icon: const Icon(Icons.clear)),
      ),
      child: Text(value == null ? 'Not set' : DateFormat.yMMMd().format(value)),
    ),
  );
}

class RecordEmiInstallmentScreen extends StatefulWidget {
  const RecordEmiInstallmentScreen({
    super.key,
    required this.controller,
    required this.emi,
  });

  final MoneyController controller;
  final EmiRecord emi;

  @override
  State<RecordEmiInstallmentScreen> createState() =>
      _RecordEmiInstallmentScreenState();
}

class _RecordEmiInstallmentScreenState
    extends State<RecordEmiInstallmentScreen> {
  final _form = GlobalKey<FormState>();
  final _principal = TextEditingController();
  final _interest = TextEditingController();
  late DateTime _date;
  bool _paid = true;
  bool _saving = false;
  int _gstBasisPoints = 1800;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, widget.emi.billingDay);
    if (candidate.isBefore(widget.emi.startDate)) {
      candidate = widget.emi.startDate;
    }
    final end = widget.emi.endDate;
    if (end != null && candidate.isAfter(end)) candidate = end;
    _date = candidate;
    widget.controller.loadGstBasisPoints().then((value) {
      if (mounted) setState(() => _gstBasisPoints = value);
    });
    _interest.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _interest.removeListener(_refresh);
    _principal.dispose();
    _interest.dispose();
    super.dispose();
  }

  int get _gstPaise =>
      ((_parseNonNegativePaise(_interest.text) ?? 0) * _gstBasisPoints +
          5000) ~/
      10000;

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.emi.startDate,
      lastDate: widget.emi.endDate ?? DateTime(2100),
      selectableDayPredicate: (date) => date.day <= 28,
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final principal = _parseNonNegativePaise(_principal.text)!;
    final interest = _parseNonNegativePaise(_interest.text)!;
    if (principal + interest == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Principal and interest cannot both be zero.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveEmiInstallment(
        emiId: widget.emi.id!,
        principalPaise: principal,
        interestPaise: interest,
        date: _date,
        isPaid: _paid,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this monthly EMI. Check that paid principal does not exceed the remaining balance.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Record monthly EMI')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _amount(_principal, 'Principal'),
              const SizedBox(height: 18),
              _amount(_interest, 'Interest'),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text('GST (${_gstPercentText(_gstBasisPoints)}%)'),
                  subtitle: const Text('Calculated automatically on interest'),
                  trailing: Text(
                    formatMoney(_gstPaise),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _saving ? null : _chooseDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(DateFormat.yMMMd().format(_date)),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Paid'),
                subtitle: const Text(
                  'Only paid principal reduces the remaining balance.',
                ),
                value: _paid,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _paid = value),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _amount(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '₹ '),
        validator: (value) => _parseNonNegativePaise(value ?? '') == null
            ? 'Enter zero or a positive amount'
            : null,
      );
}

int? _parseNonNegativePaise(String value) {
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$')
      .firstMatch(value.trim());
  if (match == null) return null;
  return int.parse(match[1]!) * 100 +
      int.parse((match[2] ?? '').padRight(2, '0'));
}

String _amountText(int paise) =>
    '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

String _gstPercentText(int basisPoints) {
  final whole = basisPoints ~/ 100;
  final fraction = basisPoints % 100;
  return fraction == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(2, '0').replaceFirst(RegExp(r'0+$'), '')}';
}
