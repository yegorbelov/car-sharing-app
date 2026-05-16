import 'package:flutter/material.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/auth_storage.dart';
import '../../models/vehicle.dart';
import '../../services/deals_api.dart';

class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  Future<void> _openBookSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final v = vehicle;

    final token = await AuthStorage.getToken();
    if (!context.mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to request a rental.')),
      );
      return;
    }
    final me = await AuthStorage.getUser();
    if (!context.mounted) return;
    if (v.ownerUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This listing has no owner yet.')),
      );
      return;
    }
    if (me != null && me.id == v.ownerUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot book your own car.')),
      );
      return;
    }

    var days = 3;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              final hold = (v.pricePerDayCents * days / 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Request rental',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(v.title, style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'A security hold of \$$hold will be placed on your wallet.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('$days ${days == 1 ? 'day' : 'days'}',
                            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text('· \$${v.pricePerDay.toStringAsFixed(0)}/day',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        Expanded(
                          child: Slider(
                            value: days.toDouble(),
                            min: 1,
                            max: 14,
                            divisions: 13,
                            label: '$days',
                            onChanged: (x) => setModal(() => days = x.round()),
                          ),
                        ),
                      ],
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Place hold \$$hold & request'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (ok != true || !context.mounted) return;
    try {
      await DealsApi.createDeal(vehicleId: v.id, dayCount: days);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent! Check Bookings.')),
      );
      Navigator.of(context).pop();
    } on DealsApiException catch (e) {
      if (!context.mounted) return;
      final msg = switch (e.code) {
        'insufficient_funds' => 'Not enough balance for the security hold.',
        'vehicle_unavailable' => 'This car already has an active or pending booking.',
        'cannot_rent_own_car' => 'You cannot book your own car.',
        'session_expired' => 'Your session expired. Please sign in again.',
        _ => e.code,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = vehicle;

    final classIcon = switch (v.className.toLowerCase()) {
      'suv' => Icons.directions_car_filled_rounded,
      'business' => Icons.airline_seat_flat_rounded,
      _ => Icons.directions_car_rounded,
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(v.title),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero image placeholder
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primaryContainer, cs.tertiaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(classIcon, size: 80, color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Price badge row
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 22, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      v.rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        '\$${v.pricePerDay.toStringAsFixed(0)} / day',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Details card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'City',
                          value: v.city,
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Class',
                          value: _classLabel(v.className),
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          icon: Icons.attach_money_rounded,
                          label: 'Security hold',
                          value: '\$${v.pricePerDay.toStringAsFixed(0)} × trip days',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: () => _openBookSheet(context),
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Request rental'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _classLabel(String c) {
    return switch (c.toLowerCase()) {
      'sedan' => 'Sedan',
      'suv' => 'SUV',
      'economy' => 'Economy',
      'comfort' => 'Comfort',
      'business' => 'Business',
      _ => c,
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
