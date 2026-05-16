import 'package:flutter/material.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key, this.onOpenCatalog});

  final VoidCallback? onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Active',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: const Icon(Icons.event_available_outlined),
              ),
              title: const Text('No active bookings'),
              subtitle: const Text('Book a car from the catalog'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'History',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.secondaryContainer,
                child: const Icon(Icons.history),
              ),
              title: const Text('No completed trips yet'),
              subtitle: const Text('History will appear after a rental'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.directions_car_filled_rounded,
                  size: 64,
                  color: cs.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Find a car in the catalog',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onOpenCatalog,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Find a car'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
