import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Original app copy, without the Settings headline or attributed quotations.
const landingQuotes = [
  'Your money, a little clearer.',
  'Small habits. A bigger picture.',
  'Keep the split. Skip the awkward maths.',
  'A little detail. A clearer picture.',
  'Every little entry brings a little more clarity.',
  'Less to remember. More room to live.',
];

/// Shown once per app launch, never pushed onto the navigation stack.
class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key, required this.child});
  final Widget child;
  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  late final String _quote =
      landingQuotes[Random().nextInt(landingQuotes.length)];
  Timer? _timer;
  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    // Let screen-reader users finish reading and continue at their own pace.
    if (!_open && !MediaQuery.accessibleNavigationOf(context)) {
      _timer = Timer(const Duration(seconds: 2), _continue);
    }
  }

  void _continue() {
    _timer?.cancel();
    if (mounted && !_open) setState(() => _open = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_open) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 38,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'yenma',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _quote,
                    key: const ValueKey('welcome-quote'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: 36),
                  TextButton.icon(
                    onPressed: _continue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Open my money'),
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
