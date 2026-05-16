import 'package:flutter/material.dart';

class _WalletRow {
  const _WalletRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const List<_WalletRow> _rows = [
    _WalletRow(
      title: 'Hold for booking',
      subtitle: 'May 16, 2026',
      amount: '−\$50.00',
      icon: Icons.lock_clock_outlined,
    ),
    _WalletRow(
      title: 'Top-up',
      subtitle: 'May 10, 2026',
      amount: '+\$100.00',
      icon: Icons.add_circle_outline,
    ),
    _WalletRow(
      title: 'Rental charge',
      subtitle: 'May 2, 2026',
      amount: '−\$32.00',
      icon: Icons.payments_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Virtual balance',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$124.50',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Educational mock balance (no real payments)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ..._rows.map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(r.icon),
                title: Text(r.title),
                subtitle: Text(r.subtitle),
                trailing: Text(
                  r.amount,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
