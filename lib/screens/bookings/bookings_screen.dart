import 'package:flutter/material.dart';

import '../../models/rental_deal.dart';
import '../../services/deals_api.dart';
import '../deals/deal_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.onOpenCatalog, required this.tabVisible});

  final VoidCallback? onOpenCatalog;
  final bool tabVisible;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<RentalDeal> _deals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BookingsScreen oldWidget) {
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
      final list = await DealsApi.fetchMine();
      if (!mounted) return;
      setState(() {
        _deals = list;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
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
                : _deals.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 48),
                          Icon(Icons.directions_car_filled_rounded, size: 64, color: cs.outline),
                          const SizedBox(height: 16),
                          Text(
                            'No deals yet',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Request a car from the catalog.\nFunds are held until the owner accepts.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: FilledButton.icon(
                              onPressed: widget.onOpenCatalog,
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Find a car'),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _deals.length,
                        itemBuilder: (context, i) {
                          final d = _deals[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: d.isOwner ? cs.secondaryContainer : cs.primaryContainer,
                                  child: Icon(
                                    d.isOwner ? Icons.key_rounded : Icons.directions_car_rounded,
                                    color: d.isOwner ? cs.onSecondaryContainer : cs.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(d.vehicleTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _StatusChip(status: d.status),
                                        const SizedBox(width: 8),
                                        Text(
                                          d.isOwner ? 'You are owner' : 'You are renter',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hold \$${(d.holdAmountCents / 100).toStringAsFixed(0)} · ${d.dayCount} days',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final changed = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: d.id)),
                                  );
                                  if (changed == true && mounted) _load();
                                },
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'pending_owner' => ('Pending', cs.tertiaryContainer, cs.onTertiaryContainer),
      'active' => ('Active', cs.primaryContainer, cs.onPrimaryContainer),
      'completed' => ('Done', cs.secondaryContainer, cs.onSecondaryContainer),
      'cancelled' => ('Cancelled', cs.errorContainer, cs.onErrorContainer),
      _ => (status, cs.surfaceContainerHighest, cs.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
