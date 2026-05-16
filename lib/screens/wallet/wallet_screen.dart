import 'package:flutter/material.dart';

import '../../models/rental_deal.dart';
import '../../services/deals_api.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.tabVisible});

  final bool tabVisible;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabVisible && !oldWidget.tabVisible) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await DealsApi.fetchWallet();
      if (!mounted) return;
      setState(() {
        _data = w;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _entryLabel(String t) {
    return switch (t) {
      'hold' => 'Security hold',
      'release_hold' => 'Hold released',
      'payout_owner' => 'Rental payout',
      _ => t,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 48),
                      Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      Center(child: FilledButton(onPressed: _load, child: const Text('Retry'))),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // Balance card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available balance',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${_data!.balance.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                      color: cs.primary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Active deals reduce your available balance until the trip completes or is cancelled.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Recent transactions',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_data!.recent.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 40, color: cs.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text(
                                  'No transactions yet',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._data!.recent.map(
                          (r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: r.deltaCents < 0 ? cs.errorContainer : cs.primaryContainer,
                                child: Icon(
                                  r.deltaCents < 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: r.deltaCents < 0 ? cs.onErrorContainer : cs.onPrimaryContainer,
                                ),
                              ),
                              title: Text(_entryLabel(r.entryType)),
                              subtitle: Text(
                                r.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                '${r.deltaCents < 0 ? '−' : '+'}​\$${(r.deltaCents.abs() / 100).toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: r.deltaCents < 0 ? cs.error : cs.primary,
                                    ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
