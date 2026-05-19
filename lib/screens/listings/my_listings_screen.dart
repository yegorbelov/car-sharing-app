import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api_config.dart';
import '../../models/vehicle.dart';
import '../../services/vehicles_api.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/completed_trips_label.dart';
import '../../widgets/listing_status_style.dart';
import '../catalog/vehicle_detail_screen.dart';
import '../profile/create_listing_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({
    super.key,
    required this.tabVisible,
    this.onListingsChanged,
  });

  final bool tabVisible;
  final VoidCallback? onListingsChanged;

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MyListingsScreen oldWidget) {
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
      final list = await VehiclesApi.fetchMine();
      if (!mounted) return;
      setState(() {
        _vehicles = list;
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

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (!mounted) return;
    if (created == true) {
      await _load();
      widget.onListingsChanged?.call();
    }
  }

  Future<void> _openEdit(Vehicle vehicle) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateListingScreen(vehicle: vehicle),
      ),
    );
    if (!mounted) return;
    if (updated == true) {
      await _load();
      widget.onListingsChanged?.call();
    }
  }

  void _openVehicle(Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(vehicle: vehicle),
      ),
    );
  }

  Future<void> _publish(Vehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish listing?'),
        content: const Text(
          'Your listing will be sent for review. It will appear in the catalog after approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await VehiclesApi.publishListing(vehicle.id);
      if (!mounted) return;
      context.showAppSnackBar(
        'Listing submitted for review.',
        kind: AppSnackBarKind.success,
      );
      await _load();
      widget.onListingsChanged?.call();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('has_active_deals')
          ? 'Cannot publish while a rental is active or pending.'
          : '$e';
      context.showAppSnackBar(msg);
    }
  }

  Future<void> _unpublish(Vehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpublish listing?'),
        content: const Text(
          'The car will be hidden from the catalog. Use Publish when you want it reviewed and listed again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await VehiclesApi.unpublishListing(vehicle.id);
      if (!mounted) return;
      context.showAppSnackBar(
        'Listing unpublished.',
        kind: AppSnackBarKind.success,
      );
      await _load();
      widget.onListingsChanged?.call();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('has_active_deals')
          ? 'Cannot unpublish while a rental is active or pending.'
          : '$e';
      context.showAppSnackBar(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('My listings'),
        backgroundColor: const Color(0xFFF4F6FA),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _openCreateListing,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New listing',
          ),
        ],
      ),
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
            : _vehicles.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: cs.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No listings yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your car to start earning.\nNew listings are reviewed before going live.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _openCreateListing,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create listing'),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _vehicles.length,
                itemBuilder: (context, i) {
                  final v = _vehicles[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _MyListingCard(
                      vehicle: v,
                      onTap: () => _openVehicle(v),
                      onEdit: () => _openEdit(v),
                      onPublish: v.canRepublish ? () => _publish(v) : null,
                      onUnpublish: v.canUnpublish ? () => _unpublish(v) : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  const _MyListingCard({
    required this.vehicle,
    required this.onTap,
    required this.onEdit,
    this.onPublish,
    this.onUnpublish,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onUnpublish;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cover = vehicle.photoUrl.isNotEmpty
        ? fullImageUrl(vehicle.photoUrl)
        : null;

    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _photoPlaceholder(cs),
                    )
                  else
                    _photoPlaceholder(cs),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: ListingStatusChip(
                      status: vehicle.listingStatus,
                      onPhoto: true,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onPublish != null)
                          IconButton.filledTonal(
                            onPressed: onPublish,
                            icon: const Icon(Icons.visibility_outlined, size: 20),
                            tooltip: 'Publish',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.92),
                              foregroundColor: const Color(0xFF111111),
                            ),
                          ),
                        if (onUnpublish != null)
                          IconButton.filledTonal(
                            onPressed: onUnpublish,
                            icon: const Icon(Icons.visibility_off_outlined, size: 20),
                            tooltip: 'Unpublish',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.92),
                              foregroundColor: const Color(0xFF111111),
                            ),
                          ),
                        IconButton.filledTonal(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          tooltip: 'Edit listing',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.92),
                            foregroundColor: const Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Text(
                      vehicle.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        shadows: const [
                          Shadow(
                            color: Color(0x88000000),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (vehicle.completedTrips > 0) ...[
                    CompletedTripsLabel(count: vehicle.completedTrips, compact: true),
                    const SizedBox(height: 8),
                  ],
                  if (vehicle.isRejected && vehicle.hasModerationNote) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        vehicle.moderationNote,
                        style: tt.bodySmall?.copyWith(
                          color: const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vehicle.catalogLocationLabel,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vehicle.rating > 0) ...[
                    SvgPicture.asset(
                      'assets/icons/star.svg',
                      width: 14,
                      height: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.rating.toStringAsFixed(1),
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '\$${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(ColorScheme cs) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 56,
          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }

}
