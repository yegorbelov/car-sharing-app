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
      icon: Icons.lock_clock_rounded,
    ),
    _WalletRow(
      title: 'Top-up',
      subtitle: 'May 10, 2026',
      amount: '+\$100.00',
      icon: Icons.add_circle_outline_rounded,
    ),
    _WalletRow(
      title: 'Rental charge',
      subtitle: 'May 2, 2026',
      amount: '−\$32.00',
      icon: Icons.payments_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Virtual balance',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$124.50',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Educational mock balance (no real payments)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.surfaceContainerHigh,
                    child: Icon(r.icon, color: cs.primary),
                  ),
                  title: Text(r.title),
                  subtitle: Text(r.subtitle),
                  trailing: Text(
                    r.amount,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
