import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/money_controller.dart';
import '../../data/commitments_data.dart';
import '../../domain/money.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<SubscriptionRecord> _subscriptions = const [];
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
      final records = await widget.controller.subscriptions();
      if (mounted) setState(() => _subscriptions = records);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load subscriptions.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([SubscriptionRecord? subscription]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordSubscriptionScreen(
          controller: widget.controller,
          subscription: subscription,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openDetails(SubscriptionRecord subscription) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionDetailScreen(
          controller: widget.controller,
          subscription: subscription,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Subscriptions')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _content(),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FilledButton.icon(
        onPressed: _loading ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Record subscription'),
      ),
    ),
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
    if (_subscriptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subscriptions_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No subscriptions yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Record recurring services to keep their next billing dates in view.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        itemCount: _subscriptions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final subscription = _subscriptions[index];
          final next = nextBillingDate(subscription);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openDetails(subscription),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 92,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        subscription.isActive
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subscription.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subscription.isActive
                                    ? 'Next bill ${DateFormat.MMMd().format(next)}'
                                    : 'Paused',
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatMoney(subscription.amountPaise),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SubscriptionDetailScreen extends StatefulWidget {
  const SubscriptionDetailScreen({
    super.key,
    required this.controller,
    required this.subscription,
  });

  final MoneyController controller;
  final SubscriptionRecord subscription;

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  late SubscriptionRecord _subscription = widget.subscription;
  bool _saving = false;

  Future<void> _toggleActive() async {
    setState(() => _saving = true);
    final updated = _copySubscription(
      _subscription,
      isActive: !_subscription.isActive,
    );
    try {
      await widget.controller.saveSubscription(updated);
      if (mounted) setState(() => _subscription = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this subscription.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordSubscriptionScreen(
          controller: widget.controller,
          subscription: _subscription,
        ),
      ),
    );
    if (saved != true) return;
    final records = await widget.controller.subscriptions();
    if (!mounted) return;
    setState(() {
      _subscription = records.firstWhere((item) => item.id == _subscription.id);
    });
  }

  Future<void> _visit() async {
    final raw = _subscription.link?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    try {
      if (uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = nextBillingDate(_subscription);
    final today = DateUtils.dateOnly(DateTime.now());
    final days = next.difference(today).inDays;
    final cycleDays = _subscription.period == SubscriptionPeriod.monthly
        ? DateTime(
            next.year,
            next.month + 1,
            next.day,
          ).difference(DateTime(next.year, next.month, next.day)).inDays
        : DateTime(
            next.year + 1,
            next.month,
            next.day,
          ).difference(DateTime(next.year, next.month, next.day)).inDays;
    final progress = 1.0 - (days / cycleDays).clamp(0.0, 1.0).toDouble();
    final hasLink = _subscription.link?.trim().isNotEmpty == true;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_subscription.name),
          actions: [
            IconButton(
              tooltip: 'Edit subscription',
              onPressed: _saving ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Text(
                  _subscription.period == SubscriptionPeriod.monthly
                      ? 'MONTHLY SUBSCRIPTION'
                      : 'YEARLY SUBSCRIPTION',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 34),
                Center(
                  child: SizedBox.square(
                    dimension: 180,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 7,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          strokeCap: StrokeCap.round,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              days == 0 ? 'TODAY' : '$days',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (days != 0) const Text('DAYS'),
                            const SizedBox(height: 6),
                            Text(DateFormat.MMMd().format(next)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    formatMoney(_subscription.amountPaise),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _toggleActive,
                        child: Text(
                          _subscription.isActive ? 'Pause' : 'Activate',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: hasLink ? _visit : null,
                        child: const Text('Visit'),
                      ),
                    ),
                  ],
                ),
                if (_subscription.notifyMe) ...[
                  const SizedBox(height: 18),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.notifications_outlined),
                      title: Text('Reminder preference saved'),
                      subtitle: Text(
                        'Device notifications are not available yet.',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecordSubscriptionScreen extends StatefulWidget {
  const RecordSubscriptionScreen({
    super.key,
    required this.controller,
    this.subscription,
  });

  final MoneyController controller;
  final SubscriptionRecord? subscription;

  @override
  State<RecordSubscriptionScreen> createState() =>
      _RecordSubscriptionScreenState();
}

class _RecordSubscriptionScreenState extends State<RecordSubscriptionScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _link;
  late SubscriptionPeriod _period;
  late DateTime _billingDate;
  late bool _active;
  late bool _notifyMe;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final value = widget.subscription;
    final now = DateTime.now();
    _name = TextEditingController(text: value?.name ?? '');
    _amount = TextEditingController(
      text: value == null ? '' : _amountText(value.amountPaise),
    );
    _link = TextEditingController(text: value?.link ?? '');
    _period = value?.period ?? SubscriptionPeriod.monthly;
    _billingDate = DateTime(
      now.year,
      value?.billingMonth ?? now.month,
      value?.billingDay ?? now.day.clamp(1, 28),
    );
    _active = value?.isActive ?? true;
    _notifyMe = value?.notifyMe ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _link.dispose();
    super.dispose();
  }

  String _amountText(int paise) =>
      '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _billingDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
      selectableDayPredicate: (date) => date.day <= 28,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _billingDate = DateTime(
        selected.year,
        selected.month,
        selected.day.clamp(1, 28),
      );
    });
  }

  String? _normalizedLink() {
    final value = _link.text.trim();
    if (value.isEmpty) return null;
    return value.contains('://') ? value : 'https://$value';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveSubscription(
        SubscriptionRecord(
          id: widget.subscription?.id,
          name: _name.text.trim(),
          amountPaise: parsePaise(_amount.text)!,
          billingDay: _billingDate.day,
          billingMonth: _billingDate.month,
          period: _period,
          isActive: _active,
          notifyMe: _notifyMe,
          link: _normalizedLink(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this subscription. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subscription == null
              ? 'Record Subscription'
              : 'Edit Subscription',
        ),
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a subscription name'
                      : null,
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
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _saving ? null : _chooseDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Billing date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _period == SubscriptionPeriod.monthly
                          ? 'Day ${_billingDate.day} of every month'
                          : DateFormat.MMMMd().format(_billingDate),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<SubscriptionPeriod>(
                  initialValue: _period,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: SubscriptionPeriod.monthly,
                      child: Text('Monthly'),
                    ),
                    DropdownMenuItem(
                      value: SubscriptionPeriod.yearly,
                      child: Text('Yearly'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _period = value!),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _link,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Link (optional)',
                    hintText: 'example.com/account',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    final uri = Uri.tryParse(_normalizedLink()!);
                    return uri != null &&
                            (uri.scheme == 'https' || uri.scheme == 'http') &&
                            uri.host.isNotEmpty
                        ? null
                        : 'Enter a valid web link';
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Active'),
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _active = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Notify me'),
                  subtitle: const Text(
                    'Saves your preference; device reminders are coming later.',
                  ),
                  value: _notifyMe,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _notifyMe = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
    ),
  );
}

DateTime nextBillingDate(SubscriptionRecord subscription, {DateTime? from}) {
  final today = DateUtils.dateOnly(from ?? DateTime.now());
  if (subscription.period == SubscriptionPeriod.monthly) {
    var next = DateTime(today.year, today.month, subscription.billingDay);
    if (next.isBefore(today)) {
      next = DateTime(today.year, today.month + 1, subscription.billingDay);
    }
    return next;
  }
  var next = DateTime(
    today.year,
    subscription.billingMonth,
    subscription.billingDay,
  );
  if (next.isBefore(today)) {
    next = DateTime(
      today.year + 1,
      subscription.billingMonth,
      subscription.billingDay,
    );
  }
  return next;
}

SubscriptionRecord _copySubscription(
  SubscriptionRecord value, {
  bool? isActive,
}) => SubscriptionRecord(
  id: value.id,
  name: value.name,
  amountPaise: value.amountPaise,
  billingDay: value.billingDay,
  billingMonth: value.billingMonth,
  period: value.period,
  isActive: isActive ?? value.isActive,
  notifyMe: value.notifyMe,
  link: value.link,
);
