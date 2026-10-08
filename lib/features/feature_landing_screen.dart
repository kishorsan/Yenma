import 'package:flutter/material.dart';

class FeatureLandingScreen extends StatelessWidget {
  const FeatureLandingScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> sections;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 26, child: Icon(icon)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(description),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'DESIGN AREAS',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.circle_outlined, size: 20),
                    title: Text(section),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'The screen structure is in place. Data entry and persistence will be connected in its feature milestone.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
