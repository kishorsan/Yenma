import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../data/commitments_data.dart';
import '../../domain/money.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  List<LoanRecord> _loans = const [];
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
      final loans = await widget.controller.loans();
      if (mounted) setState(() => _loans = loans);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load loans.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _record([LoanRecord? loan]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordLoanScreen(controller: widget.controller, loan: loan),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _open(LoanRecord loan) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoanDetailScreen(controller: widget.controller, loan: loan),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Loans')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _record(),
      icon: const Icon(Icons.add),
      label: const Text('Record loan'),
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
    if (_loans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_outlined, size: 54),
              const SizedBox(height: 18),
              Text(
                'No loans yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Track a loan balance, upcoming repayments, and payment history.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _record(),
                child: const Text('Record loan'),
              ),
            ],
          ),
        ),
      );
    }

    final active = _loans.where((loan) => !loan.isComplete).toList();
    final completed = _loans.where((loan) => loan.isComplete).toList();
    final outstanding = active.fold<int>(
      0,
      (sum, loan) => sum + loan.remainingPaise,
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
                    'TOTAL OUTSTANDING',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(outstanding),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${active.length} active · ${completed.length} completed',
                  ),
                ],
              ),
            ),
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('Active loans'),
            const SizedBox(height: 10),
            ...active.map(_card),
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 24),
            _heading('Completed'),
            const SizedBox(height: 10),
            ...completed.map(_card),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _card(LoanRecord loan) {
    final progress = loan.totalAmountPaise == 0
        ? 0.0
        : loan.amountPaidPaise / loan.totalAmountPaise;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(loan),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Icon(_loanIcon(loan.type))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(_loanTypeLabel(loan.type)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(loan.isComplete ? 'Fully paid' : 'Remaining'),
                    const Spacer(),
                    Text(
                      formatMoney(loan.remainingPaise),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress.clamp(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoanDetailScreen extends StatefulWidget {
  const LoanDetailScreen({
    super.key,
    required this.controller,
    required this.loan,
  });

  final MoneyController controller;
  final LoanRecord loan;

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  late LoanRecord _loan = widget.loan;
  List<LoanTrackingRecord> _payments = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loans = await widget.controller.loans();
    final payments = await widget.controller.loanPayments(_loan.id!);
    if (!mounted) return;
    setState(() {
      _loan = loans.firstWhere((loan) => loan.id == _loan.id);
      _payments = payments;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecordLoanScreen(controller: widget.controller, loan: _loan),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _recordPayment([LoanTrackingRecord? payment]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordLoanPaymentScreen(
          controller: widget.controller,
          loan: _loan,
          payment: payment,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_loan.name),
      actions: [
        IconButton(
          onPressed: _edit,
          tooltip: 'Edit loan',
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    floatingActionButton: _loan.isComplete
        ? null
        : FloatingActionButton.extended(
            onPressed: _recordPayment,
            icon: const Icon(Icons.add),
            label: const Text('Record payment'),
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
                            _loan.isComplete ? 'FULLY PAID' : 'OUTSTANDING',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatMoney(_loan.remainingPaise),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                (_loan.amountPaidPaise / _loan.totalAmountPaise)
                                    .clamp(0, 1),
                          ),
                          const Divider(height: 32),
                          _fact(
                            'Original amount',
                            formatMoney(_loan.totalAmountPaise),
                          ),
                          _fact(
                            'Principal paid',
                            formatMoney(_loan.amountPaidPaise),
                          ),
                          _fact('Loan type', _loanTypeLabel(_loan.type)),
                          _fact(
                            'Started',
                            DateFormat.yMMMd().format(_loan.startDate),
                          ),
                          if (_loan.endDate != null)
                            _fact(
                              'Expected end',
                              DateFormat.yMMMd().format(_loan.endDate!),
                            ),
                          if (_loan.note.isNotEmpty) ...[
                            const Divider(height: 28),
                            Text(_loan.note),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Payment schedule',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  const Text('Tap an entry to update it.'),
                  const SizedBox(height: 10),
                  if (_payments.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No payments scheduled yet.'),
                        subtitle: Text(
                          'Add a paid repayment or an upcoming amount due.',
                        ),
                      ),
                    )
                  else
                    ..._payments.map(_paymentCard),
                ],
              ),
      ),
    ),
  );

  Widget _paymentCard(LoanTrackingRecord payment) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        onTap: () => _recordPayment(payment),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(
          payment.isPaid ? Icons.check_circle_outline : Icons.schedule_outlined,
        ),
        title: Text(
          formatMoney(
            payment.principalPaise + payment.interestPaise + payment.gstPaise,
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${DateFormat.yMMMd().format(payment.date)} · Principal ${formatMoney(payment.principalPaise)}\n'
          'Interest ${formatMoney(payment.interestPaise)}'
          '${payment.gstPaise == 0 ? '' : ' · Charges ${formatMoney(payment.gstPaise)}'}',
        ),
        isThreeLine: true,
        trailing: Text(payment.isPaid ? 'Paid' : 'Due'),
      ),
    ),
  );

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class RecordLoanScreen extends StatefulWidget {
  const RecordLoanScreen({super.key, required this.controller, this.loan});

  final MoneyController controller;
  final LoanRecord? loan;

  @override
  State<RecordLoanScreen> createState() => _RecordLoanScreenState();
}

class _RecordLoanScreenState extends State<RecordLoanScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late LoanType _type;
  late DateTime _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    final now = DateTime.now();
    _name = TextEditingController(text: loan?.name ?? '');
    _amount = TextEditingController(
      text: loan == null ? '' : _amountText(loan.totalAmountPaise),
    );
    _note = TextEditingController(text: loan?.note ?? '');
    _type = loan?.type ?? LoanType.emiAmortizing;
    _start = loan?.startDate ?? DateTime(now.year, now.month, now.day);
    _end = loan?.endDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _choose(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }
    final amount = parsePaise(_amount.text)!;
    if (amount < (widget.loan?.amountPaidPaise ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The loan amount cannot be less than principal already paid.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveLoan(
        LoanRecord(
          id: widget.loan?.id,
          name: _name.text.trim(),
          totalAmountPaise: amount,
          amountPaidPaise: widget.loan?.amountPaidPaise ?? 0,
          note: _note.text.trim(),
          startDate: _start,
          endDate: _end,
          status: widget.loan?.status ?? LoanStatus.pending,
          type: _type,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this loan. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.loan == null ? 'Record loan' : 'Edit loan'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Loan name or lender',
                  hintText: 'Home loan, ABC Bank…',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a loan name or lender'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Original loan amount',
                  prefixText: '₹ ',
                ),
                validator: (value) => parsePaise(value ?? '') == null
                    ? 'Enter an amount greater than zero'
                    : null,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<LoanType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Repayment type'),
                items: LoanType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_loanTypeLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 8),
              Text(_loanTypeHelp(_type)),
              const SizedBox(height: 18),
              _dateField('Start date', _start, () async {
                final value = await _choose(_start);
                if (value != null) setState(() => _start = value);
              }),
              const SizedBox(height: 18),
              _dateField(
                'Expected end date (optional)',
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
                decoration: const InputDecoration(
                  labelText: 'Account, rate, or note (optional)',
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _dateField(
    String label,
    DateTime? value,
    VoidCallback select, {
    VoidCallback? clear,
  }) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Row(
      children: [
        Expanded(
          child: Text(
            value == null ? 'Not set' : DateFormat.yMMMd().format(value),
          ),
        ),
        if (clear != null)
          IconButton(
            onPressed: clear,
            tooltip: 'Clear date',
            icon: const Icon(Icons.clear),
          ),
        IconButton(
          onPressed: _saving ? null : select,
          tooltip: 'Choose date',
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    ),
  );
}

class RecordLoanPaymentScreen extends StatefulWidget {
  const RecordLoanPaymentScreen({
    super.key,
    required this.controller,
    required this.loan,
    this.payment,
  });

  final MoneyController controller;
  final LoanRecord loan;
  final LoanTrackingRecord? payment;

  @override
  State<RecordLoanPaymentScreen> createState() =>
      _RecordLoanPaymentScreenState();
}

class _RecordLoanPaymentScreenState extends State<RecordLoanPaymentScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _principal;
  late final TextEditingController _interest;
  late final TextEditingController _charges;
  late DateTime _date;
  late bool _isPaid;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _principal = TextEditingController(
      text: payment == null ? '' : _amountText(payment.principalPaise),
    );
    _interest = TextEditingController(
      text: payment == null ? '0' : _amountText(payment.interestPaise),
    );
    _charges = TextEditingController(
      text: payment == null ? '0' : _amountText(payment.gstPaise),
    );
    _date = payment?.date ?? _dateWithinLoan(today, widget.loan);
    _isPaid = payment?.isPaid ?? true;
  }

  @override
  void dispose() {
    _principal.dispose();
    _interest.dispose();
    _charges.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.loan.startDate,
      lastDate: widget.loan.endDate ?? DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final principal = _parseNonNegativePaise(_principal.text)!;
    final interest = _parseNonNegativePaise(_interest.text)!;
    final charges = _parseNonNegativePaise(_charges.text)!;
    if (principal + interest + charges == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one payment amount.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveLoanPayment(
        LoanTrackingRecord(
          id: widget.payment?.id,
          loanId: widget.loan.id!,
          principalPaise: principal,
          interestPaise: interest,
          gstPaise: charges,
          date: _date,
          isPaid: _isPaid,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save this payment. Paid principal cannot exceed the outstanding balance.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.payment == null ? 'Record payment' : 'Edit payment'),
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
                widget.loan.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('${formatMoney(widget.loan.remainingPaise)} outstanding'),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.check),
                    label: Text('Paid'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.schedule),
                    label: Text('Due'),
                  ),
                ],
                selected: {_isPaid},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() => _isPaid = value.single),
              ),
              const SizedBox(height: 18),
              _moneyField(_principal, 'Principal'),
              const SizedBox(height: 18),
              _moneyField(_interest, 'Interest'),
              const SizedBox(height: 18),
              _moneyField(_charges, 'Fees or charges'),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_isPaid ? 'Payment date' : 'Due date'),
                subtitle: Text(DateFormat.yMMMd().format(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _saving ? null : _chooseDate,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _moneyField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '₹ '),
        validator: (value) => _parseNonNegativePaise(value ?? '') == null
            ? 'Enter zero or a valid amount'
            : null,
      );
}

String _loanTypeLabel(LoanType type) => switch (type) {
  LoanType.revolving => 'Revolving credit',
  LoanType.oneTime => 'Single repayment',
  LoanType.emiAmortizing => 'Regular repayments',
};

String _loanTypeHelp(LoanType type) => switch (type) {
  LoanType.revolving => 'For a reusable credit line whose balance changes.',
  LoanType.oneTime => 'For an amount expected to be settled in one repayment.',
  LoanType.emiAmortizing => 'For a loan repaid through multiple instalments.',
};

IconData _loanIcon(LoanType type) => switch (type) {
  LoanType.revolving => Icons.autorenew,
  LoanType.oneTime => Icons.looks_one_outlined,
  LoanType.emiAmortizing => Icons.account_balance_outlined,
};

DateTime _dateWithinLoan(DateTime candidate, LoanRecord loan) {
  if (candidate.isBefore(loan.startDate)) return loan.startDate;
  if (loan.endDate != null && candidate.isAfter(loan.endDate!)) {
    return loan.endDate!;
  }
  return candidate;
}

int? _parseNonNegativePaise(String value) {
  final text = value.trim();
  if (text == '0' || text == '0.0' || text == '0.00') return 0;
  return parsePaise(text);
}

String _amountText(int paise) =>
    '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
