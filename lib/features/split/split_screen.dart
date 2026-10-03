import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/money_controller.dart';
import '../../domain/money.dart';
import '../../domain/split.dart';

class SplitGroupsScreen extends StatefulWidget {
  const SplitGroupsScreen({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<SplitGroupsScreen> createState() => _SplitGroupsScreenState();
}

class _SplitGroupsScreenState extends State<SplitGroupsScreen> {
  List<SplitGroup> _groups = const [];
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
      final groups = await widget.controller.splitGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load split groups.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CreateSplitGroupScreen(controller: widget.controller),
      ),
    );
    if (id == null || !mounted) return;
    await _load();
    final group = _groups.where((item) => item.id == id).firstOrNull;
    if (group != null && mounted) await _openGroup(group);
  }

  Future<void> _openGroup(SplitGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SplitGroupScreen(controller: widget.controller, group: group),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Split')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(onRefresh: _load, child: _content()),
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading ? null : _createGroup,
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Create group'),
    ),
  );

  Widget _content() {
    if (_loading) {
      return ListView(
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 160),
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    if (_groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 130),
          Icon(
            Icons.people_outline,
            size: 58,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Split together, remember once',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a reusable group for trips, home, or meals. Every split stays in one conversation.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final activity = group.lastActivity ?? group.createdAt;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openGroup(group),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  _InitialsAvatar(label: group.name),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.members.length + 1} people · ${group.members.map((member) => member.name).join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          group.lastActivity == null
                              ? 'Ready for the first split'
                              : 'Latest ${DateFormat.MMMd().format(activity)}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
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

class CreateSplitGroupScreen extends StatefulWidget {
  const CreateSplitGroupScreen({super.key, required this.controller});
  final MoneyController controller;

  @override
  State<CreateSplitGroupScreen> createState() => _CreateSplitGroupScreenState();
}

class _CreateSplitGroupScreenState extends State<CreateSplitGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _member = TextEditingController();
  final _members = <String>[];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _member.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _member.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return;
    if (!_members.any((item) => item.toLowerCase() == name.toLowerCase())) {
      setState(() => _members.add(name));
    }
    _member.clear();
  }

  Future<void> _save() async {
    _addMember();
    if (!_form.currentState!.validate()) return;
    if (_members.isEmpty) {
      setState(() => _error = 'Add at least one person.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.controller.createSplitGroup(
        name: _name.text,
        note: _note.text,
        memberNames: _members,
      );
      if (mounted) Navigator.pop(context, id);
    } on SplitValidationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not create this group.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  key: const Key('split_group_name'),
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    hintText: 'e.g. Goa trip',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a group name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'People',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('split_member_name'),
                        controller: _member,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addMember(),
                        decoration: const InputDecoration(
                          labelText: 'Person name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Add person',
                      onPressed: _saving ? null : _addMember,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _members
                      .map(
                        (member) => InputChip(
                          avatar: _InitialsAvatar(label: member, radius: 13),
                          label: Text(member),
                          onDeleted: _saving
                              ? null
                              : () => setState(() => _members.remove(member)),
                        ),
                      )
                      .toList(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
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
                  child: Text(_saving ? 'Saving…' : 'Create group'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SplitGroupScreen extends StatefulWidget {
  const SplitGroupScreen({
    super.key,
    required this.controller,
    required this.group,
  });
  final MoneyController controller;
  final SplitGroup group;

  @override
  State<SplitGroupScreen> createState() => _SplitGroupScreenState();
}

class _SplitGroupScreenState extends State<SplitGroupScreen> {
  List<SplitEntry> _entries = const [];
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
      final entries = await widget.controller.splitEntries(widget.group.id);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load this split history.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _record() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordSplitScreen(
          controller: widget.controller,
          group: widget.group,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.group.name),
          Text(
            '${widget.group.members.length + 1} people',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              _memberStrip(),
              const Divider(height: 1),
              Expanded(child: _content()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _record,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Record split'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _memberStrip() => SizedBox(
    height: 76,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      children: [
        const _MemberBadge(name: 'Me'),
        ...widget.group.members.map(
          (member) => _MemberBadge(name: member.name),
        ),
      ],
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
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'No splits yet. Record the first shared expense and it will appear here like a conversation.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _SplitBubble(entry: _entries[index]),
      ),
    );
  }
}

class RecordSplitScreen extends StatefulWidget {
  const RecordSplitScreen({
    super.key,
    required this.controller,
    required this.group,
  });
  final MoneyController controller;
  final SplitGroup group;

  @override
  State<RecordSplitScreen> createState() => _RecordSplitScreenState();
}

class _RecordSplitScreenState extends State<RecordSplitScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _total = TextEditingController();
  final _note = TextEditingController();
  late final List<_ShareInput> _shares;
  bool _impersonating = false;
  int? _payerId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shares = [
      _ShareInput.me(),
      ...widget.group.members.map(_ShareInput.member),
    ];
    _payerId = widget.group.members.firstOrNull?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _note.dispose();
    for (final share in _shares) {
      share.amount.dispose();
    }
    super.dispose();
  }

  void _splitEqually() {
    final total = parsePaise(_total.text);
    final selected = _shares.where((share) => share.selected).toList();
    if (total == null || selected.isEmpty) {
      setState(
        () => _error = 'Enter a total and select at least one participant.',
      );
      return;
    }
    final base = total ~/ selected.length;
    var remainder = total % selected.length;
    for (final share in _shares) {
      if (!share.selected) {
        share.amount.clear();
        continue;
      }
      final value = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      share.amount.text = _amountText(value);
    }
    setState(() => _error = null);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_shares
        .where((share) => share.selected)
        .any((share) => parsePaise(share.amount.text) == null)) {
      _splitEqually();
    }
    final total = parsePaise(_total.text)!;
    final shares = _shares
        .where((share) => share.selected)
        .map(
          (share) => SplitEntryShare(
            associateId: share.member?.id,
            name: share.name,
            isMe: share.isMe,
            amountPaise: parsePaise(share.amount.text) ?? 0,
          ),
        )
        .toList();
    if (shares.isEmpty || shares.any((share) => share.amountPaise <= 0)) {
      setState(() => _error = 'Select participants and enter each share.');
      return;
    }
    final sum = shares.fold<int>(
      0,
      (value, share) => value + share.amountPaise,
    );
    if (sum != total) {
      setState(
        () => _error =
            'Shares add up to ${formatMoney(sum)}, not ${formatMoney(total)}.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveSplitEntry(
        SplitEntryDraft(
          groupId: widget.group.id,
          title: _title.text,
          amountPaise: total,
          date: DateTime.now(),
          payerAssociateId: _impersonating ? _payerId : null,
          shares: shares,
          note: _note.text,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on SplitValidationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not record this split.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Record split')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  key: const Key('split_title'),
                  controller: _title,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What was this for?',
                    hintText: 'e.g. Dinner',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a description'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('split_total'),
                  controller: _total,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total',
                    prefixText: '₹ ',
                  ),
                  validator: (value) => parsePaise(value ?? '') == null
                      ? 'Enter a positive amount'
                      : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  key: const Key('split_impersonation'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Record for someone else'),
                  subtitle: const Text(
                    'The split is saved as if this person paid.',
                  ),
                  value: _impersonating,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _impersonating = value),
                ),
                if (_impersonating) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _payerId,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: widget.group.members
                        .map(
                          (member) => DropdownMenuItem(
                            value: member.id,
                            child: Text(member.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _payerId = value),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Split between',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : _splitEqually,
                      icon: const Icon(Icons.balance_outlined),
                      label: const Text('Split equally'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._shares.map(
                  (share) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Checkbox(
                          value: share.selected,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  share.selected = value ?? false;
                                  if (!share.selected) share.amount.clear();
                                }),
                        ),
                        _InitialsAvatar(label: share.name, radius: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(share.name)),
                        SizedBox(
                          width: 126,
                          child: TextField(
                            key: Key(
                              share.isMe
                                  ? 'split_share_me'
                                  : 'split_share_${share.member!.id}',
                            ),
                            controller: share.amount,
                            enabled: !_saving && share.selected,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              hintText: '0.00',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
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
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: _saving || (_impersonating && _payerId == null)
                      ? null
                      : _save,
                  child: Text(_saving ? 'Saving…' : 'Record split'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SplitBubble extends StatelessWidget {
  const _SplitBubble({required this.entry});
  final SplitEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = entry.recordedForSomeoneElse
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = entry.recordedForSomeoneElse
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final debtShares = entry.shares
        .where((share) => share.debtId != null)
        .toList();
    final settled =
        debtShares.isNotEmpty &&
        debtShares.every((share) => share.remainingPaise == 0);
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .84,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(
                entry.recordedForSomeoneElse ? 22 : 5,
              ),
              bottomRight: Radius.circular(
                entry.recordedForSomeoneElse ? 5 : 22,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.payerName} paid',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      DateFormat.MMMd().format(entry.date),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(entry.amountPaise),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: entry.shares
                      .map(
                        (share) => Chip(
                          label: Text(
                            '${share.name} ${formatMoney(share.amountPaise)}',
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(entry.note),
                ],
                if (debtShares.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        settled ? Icons.check_circle_outline : Icons.schedule,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        settled ? 'Settled' : 'Tracked in Debt',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
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

class _MemberBadge extends StatelessWidget {
  const _MemberBadge({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: Row(
      children: [
        _InitialsAvatar(label: name, radius: 18),
        const SizedBox(width: 7),
        Text(name, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.label, this.radius = 24});
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final words = label.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase())
        .join();
    return CircleAvatar(radius: radius, child: Text(initials));
  }
}

class _ShareInput {
  _ShareInput.me() : isMe = true, name = 'Me', member = null;
  _ShareInput.member(this.member) : isMe = false, name = member!.name;

  final bool isMe;
  final String name;
  final SplitMember? member;
  bool selected = true;
  final amount = TextEditingController();
}

String _amountText(int paise) =>
    '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}';
