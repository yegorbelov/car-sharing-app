import 'package:flutter/material.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key, this.onOpenCatalog});

  final VoidCallback? onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Active',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('No active bookings'),
              subtitle: const Text('Book a car from the catalog'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'History',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('No completed trips yet'),
              subtitle: const Text('History will appear after a rental'),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.directions_car_filled_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
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
                  icon: const Icon(Icons.search),
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
