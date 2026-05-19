import 'package:flutter/material.dart';

import '../../models/rental_deal.dart';
import '../../services/deals_api.dart';
import '../../widgets/illustrated_empty_state.dart';
import '../deals/deal_detail_screen.dart';

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

  /// `null` = all types.
  String? _typeFilter;

  static const _typeFilters = <(String?, String, IconData)>[
    (null, 'All', Icons.receipt_long_outlined),
    ('hold', 'Holds', Icons.lock_clock_outlined),
    ('release_hold', 'Released', Icons.lock_open_outlined),
    ('payout_owner', 'Payouts', Icons.payments_outlined),
  ];

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

  Future<void> _openDeal(LedgerEntry entry) async {
    final dealId = entry.dealId;
    if (dealId == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: dealId)),
    );
    if (changed == true && mounted) _load();
  }

  int _reservedCents(List<LedgerEntry> entries) {
    final netByDeal = <int, int>{};
    for (final e in entries) {
      final id = e.dealId;
      if (id == null) continue;
      netByDeal[id] = (netByDeal[id] ?? 0) + e.deltaCents;
    }
    var reserved = 0;
    for (final net in netByDeal.values) {
      if (net < 0) reserved += -net;
    }
    return reserved;
  }

  List<LedgerEntry> _filteredEntries() {
    final all = _data?.recent ?? [];
    if (_typeFilter == null) return all;
    return all.where((e) => e.entryType == _typeFilter).toList();
  }

  Map<String, List<LedgerEntry>> _groupByDay(List<LedgerEntry> entries) {
    final groups = <String, List<LedgerEntry>>{};
    for (final e in entries) {
      final key = _WalletFormat.dayLabel(e.createdAt);
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups;
  }

  List<_WalletDayItem> _itemsForDay(List<LedgerEntry> dayEntries) {
    final standalone = <LedgerEntry>[];
    final byDeal = <int, List<LedgerEntry>>{};

    for (final e in dayEntries) {
      final id = e.dealId;
      if (id != null) {
        byDeal.putIfAbsent(id, () => []).add(e);
      } else {
        standalone.add(e);
      }
    }

    final items = <_WalletDayItem>[
      for (final e in standalone) _WalletStandaloneEntry(e),
      for (final e in byDeal.entries)
        _WalletOrderGroup(
          dealId: e.key,
          entries: _sortEntriesNewestFirst(e.value),
        ),
    ];

    items.sort((a, b) => _itemSortKey(b).compareTo(_itemSortKey(a)));
    return items;
  }

  List<LedgerEntry> _sortEntriesNewestFirst(List<LedgerEntry> entries) {
    final copy = List<LedgerEntry>.from(entries);
    copy.sort((a, b) {
      final ta = _WalletFormat.parse(a.createdAt);
      final tb = _WalletFormat.parse(b.createdAt);
      if (ta == null && tb == null) return b.id.compareTo(a.id);
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return copy;
  }

  DateTime _itemSortKey(_WalletDayItem item) {
    return switch (item) {
      _WalletStandaloneEntry(:final entry) =>
        _WalletFormat.parse(entry.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      _WalletOrderGroup(:final entries) =>
        _WalletFormat.parse(entries.first.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  Future<void> _openDealById(int dealId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: dealId)),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = _filteredEntries();
    final all = _data?.recent ?? [];
    final hasAny = all.isNotEmpty;
    final reserved = _reservedCents(all);
    final grouped = _groupByDay(filtered);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: const Color(0xFFF4F6FA),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _BalanceHero(
                    balance: _data!.balance,
                    reservedCents: reserved,
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Transactions',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _typeFilters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final (value, label, icon) = _typeFilters[i];
                        final selected = _typeFilter == value;
                        return FilterChip(
                          showCheckmark: false,
                          avatar: Icon(
                            icon,
                            size: 16,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _typeFilter = value),
                          labelStyle: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? cs.onPrimary : cs.onSurface,
                          ),
                          selectedColor: cs.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: selected
                                ? cs.primary
                                : const Color(0xFFE2E6EF),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!hasAny)
                    const IllustratedEmptyState(
                      assetPath: IllustratedEmptyState.walletEmpty,
                      title: 'No transactions yet',
                      subtitle:
                          'Security holds and rental payouts from your orders will appear here.',
                      illustrationHeight: 160,
                    )
                  else if (filtered.isEmpty)
                    _EmptyFilterState(
                      onClear: () => setState(() => _typeFilter = null),
                    )
                  else
                    ...grouped.entries.expand((group) {
                      return [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                          child: Text(
                            group.key,
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ..._itemsForDay(group.value).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: switch (item) {
                              _WalletStandaloneEntry(:final entry) =>
                                _TransactionTile(
                                  entry: entry,
                                  onTap: entry.hasDeal
                                      ? () => _openDeal(entry)
                                      : null,
                                ),
                              _WalletOrderGroup(:final dealId, :final entries) =>
                                _OrderTransactionGroup(
                                  dealId: dealId,
                                  entries: entries,
                                  onOpenDeal: () => _openDealById(dealId),
                                ),
                            },
                          );
                        }),
                      ];
                    }),
                ],
              ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance, required this.reservedCents});

  final double balance;
  final int reservedCents;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.35)!],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: cs.onPrimary.withValues(alpha: 0.9),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Available balance',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '\$${balance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: cs.onPrimary,
                height: 1.05,
              ),
            ),
            if (reservedCents > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: cs.onPrimary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '\$${(reservedCents / 100).toStringAsFixed(2)} reserved in active orders',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Funds are held when you book a car and released when the trip ends or is cancelled.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _WalletDayItem {}

class _WalletStandaloneEntry extends _WalletDayItem {
  _WalletStandaloneEntry(this.entry);
  final LedgerEntry entry;
}

class _WalletOrderGroup extends _WalletDayItem {
  _WalletOrderGroup({required this.dealId, required this.entries});

  final int dealId;
  final List<LedgerEntry> entries;

  int get netCents => entries.fold(0, (s, e) => s + e.deltaCents);

  LedgerEntry get primary => entries.first;

  String? get vehicleTitle {
    for (final e in entries) {
      final t = e.vehicleTitle?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  String? get dealStatus {
    for (final e in entries) {
      final s = e.dealStatus?.trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }
}

class _OrderTransactionGroup extends StatefulWidget {
  const _OrderTransactionGroup({
    required this.dealId,
    required this.entries,
    required this.onOpenDeal,
  });

  final int dealId;
  final List<LedgerEntry> entries;
  final VoidCallback onOpenDeal;

  @override
  State<_OrderTransactionGroup> createState() => _OrderTransactionGroupState();
}

class _OrderTransactionGroupState extends State<_OrderTransactionGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final group = _WalletOrderGroup(
      dealId: widget.dealId,
      entries: widget.entries,
    );
    final title = group.vehicleTitle ?? 'Order #${widget.dealId}';
    final net = group.netCents;
    final isDebit = net < 0;
    final netLabel = '${isDebit ? '−' : '+'}\$${(net.abs() / 100).toStringAsFixed(2)}';
    final count = widget.entries.length;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onOpenDeal,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.directions_car_outlined,
                            size: 22,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Order #${widget.dealId} · $count ${count == 1 ? 'transaction' : 'transactions'}',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (group.dealStatus != null) ...[
                                const SizedBox(height: 6),
                                _DealStatusPill(status: group.dealStatus!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      netLabel,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDebit
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Net',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                for (var i = 0; i < widget.entries.length; i++) ...[
                  _TransactionLine(
                    entry: widget.entries[i],
                    showDivider: i < widget.entries.length - 1,
                  ),
                ],
                InkWell(
                  onTap: widget.onOpenDeal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Open order',
                          style: tt.labelLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _TransactionLine extends StatelessWidget {
  const _TransactionLine({required this.entry, this.showDivider = true});

  final LedgerEntry entry;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final meta = _WalletEntryMeta.of(entry);
    final isDebit = entry.deltaCents < 0;
    final amount = (entry.deltaCents.abs() / 100).toStringAsFixed(2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Icon(meta.icon, size: 18, color: meta.fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _WalletFormat.time(entry.createdAt),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isDebit ? '−' : '+'}\$$amount',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDebit
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 42,
            endIndent: 14,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No transactions in this category',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Show all')),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.entry, this.onTap});

  final LedgerEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final meta = _WalletEntryMeta.of(entry);
    final isDebit = entry.deltaCents < 0;
    final amount = (entry.deltaCents.abs() / 100).toStringAsFixed(2);
    final title = (entry.vehicleTitle?.trim().isNotEmpty ?? false)
        ? entry.vehicleTitle!
        : meta.title;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(meta.icon, size: 22, color: meta.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (entry.hasDeal) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (entry.dealStatus != null &&
                              entry.dealStatus!.isNotEmpty)
                            _DealStatusPill(status: entry.dealStatus!),
                          if (entry.dealStatus != null &&
                              entry.dealStatus!.isNotEmpty)
                            const SizedBox(width: 6),
                          Text(
                            'Order #${entry.dealId}',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDebit ? '−' : '+'}\$$amount',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDebit
                          ? const Color(0xFFC62828)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _WalletFormat.time(entry.createdAt),
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(height: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealStatusPill extends StatelessWidget {
  const _DealStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'pending_owner' => (
        'Pending',
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
      ),
      'active' => ('Active', cs.primaryContainer, cs.onPrimaryContainer),
      'disputed' => ('Dispute', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'completed' => ('Done', cs.secondaryContainer, cs.onSecondaryContainer),
      'cancelled' => ('Cancelled', cs.errorContainer, cs.onErrorContainer),
      _ => (status, cs.surfaceContainerHighest, cs.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _WalletEntryMeta {
  const _WalletEntryMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final Color fg;

  static _WalletEntryMeta of(LedgerEntry e) {
    return switch (e.entryType) {
      'hold' => const _WalletEntryMeta(
        title: 'Security hold',
        subtitle: 'Reserved for rental',
        icon: Icons.lock_clock_outlined,
        bg: Color(0xFFFFF3E0),
        fg: Color(0xFFE65100),
      ),
      'release_hold' => const _WalletEntryMeta(
        title: 'Hold released',
        subtitle: 'Returned to balance',
        icon: Icons.lock_open_outlined,
        bg: Color(0xFFE8F5E9),
        fg: Color(0xFF2E7D32),
      ),
      'payout_owner' => const _WalletEntryMeta(
        title: 'Rental payout',
        subtitle: 'Trip completed',
        icon: Icons.payments_outlined,
        bg: Color(0xFFE3F2FD),
        fg: Color(0xFF1565C0),
      ),
      _ => _WalletEntryMeta(
        title: e.entryType,
        subtitle: e.note,
        icon: Icons.receipt_long_outlined,
        bg: const Color(0xFFF4F6FA),
        fg: const Color(0xFF5C667A),
      ),
    };
  }
}

class _WalletFormat {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static DateTime? parse(String raw) => _parse(raw);

  static DateTime? _parse(String raw) {
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct.toLocal();
    if (raw.length >= 10) {
      final dateOnly = DateTime.tryParse(raw.substring(0, 10));
      if (dateOnly != null) return dateOnly.toLocal();
    }
    return null;
  }

  static String dayLabel(String createdAt) {
    final d = _parse(createdAt);
    if (d == null) return createdAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String time(String createdAt) {
    final d = _parse(createdAt);
    if (d == null) return '';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
