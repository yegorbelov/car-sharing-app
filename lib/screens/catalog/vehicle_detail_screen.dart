import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/api_config.dart';
import '../../core/auth_storage.dart';
import '../../models/vehicle.dart';
import '../../services/deals_api.dart';
import '../../services/vehicles_api.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Vehicle _vehicle;
  bool _uploadingPhoto = false;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final user = await AuthStorage.getUser();
    if (mounted) setState(() => _myId = user?.id);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await VehiclesApi.uploadVehiclePhoto(vehicleId: _vehicle.id, filePath: picked.path);
      if (!mounted) return;
      setState(() => _vehicle = Vehicle(
            id: _vehicle.id,
            title: _vehicle.title,
            city: _vehicle.city,
            className: _vehicle.className,
            pricePerDayCents: _vehicle.pricePerDayCents,
            rating: _vehicle.rating,
            ownerUserId: _vehicle.ownerUserId,
            photoUrl: url,
          ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _openBookSheet() async {
    final cs = Theme.of(context).colorScheme;
    final v = _vehicle;

    final token = await AuthStorage.getToken();
    if (!context.mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in to request a rental.')));
      return;
    }
    final me = await AuthStorage.getUser();
    if (!context.mounted) return;
    if (v.ownerUserId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('This listing has no owner yet.')));
      return;
    }
    if (me != null && me.id == v.ownerUserId) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You cannot book your own car.')));
      return;
    }

    var days = 3;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            final hold = (v.pricePerDayCents * days / 100).toStringAsFixed(0);
            final total = (v.pricePerDayCents * days / 100).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Request rental',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(v.title, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration',
                              style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                          Text('$days ${days == 1 ? 'day' : 'days'}',
                              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Security hold',
                              style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                          Text('\$$total',
                              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800, color: cs.primary)),
                        ],
                      ),
                    ],
                  ),
                  Slider(
                    value: days.toDouble(),
                    min: 1,
                    max: 14,
                    divisions: 13,
                    label: '$days days',
                    onChanged: (x) => setModal(() => days = x.round()),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hold of \$$hold will be placed until owner accepts or you cancel.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: Text('Place hold \$$hold & send request'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
    final v = _vehicle;
    final isOwner = _myId != null && _myId == v.ownerUserId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _VehicleHero(vehicle: v, uploading: _uploadingPhoto),
            ),
            actions: [
              if (isOwner)
                IconButton(
                  onPressed: _pickAndUploadPhoto,
                  icon: const Icon(Icons.add_a_photo_rounded),
                  tooltip: 'Update photo',
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title + price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        v.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\$${v.pricePerDay.toStringAsFixed(0)}/day',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(v.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on_rounded, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(v.city, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),

                const SizedBox(height: 24),

                // Details card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _DetailTile(
                          icon: Icons.category_outlined,
                          label: 'Class',
                          value: v.subtitle.split(' · ').last,
                        ),
                        const Divider(),
                        _DetailTile(
                          icon: Icons.lock_outline_rounded,
                          label: 'Security hold',
                          value: '\$${v.pricePerDay.toStringAsFixed(0)} × trip days',
                        ),
                        const Divider(),
                        _DetailTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Rate',
                          value: '\$${v.pricePerDay.toStringAsFixed(2)} per day',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                if (isOwner)
                  OutlinedButton.icon(
                    onPressed: _pickAndUploadPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(v.photoUrl.isNotEmpty ? 'Update photo' : 'Add a photo'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  )
                else
                  FilledButton.icon(
                    onPressed: _openBookSheet,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Request rental'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle, required this.uploading});

  final Vehicle vehicle;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = vehicle.photoUrl.isNotEmpty ? fullImageUrl(vehicle.photoUrl) : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isNotEmpty)
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholder(cs),
          )
        else
          _placeholder(cs),
        // Bottom gradient scrim so the app bar title is readable.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),
        if (uploading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.directions_car_rounded, size: 90, color: cs.onPrimaryContainer.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 20, color: cs.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      trailing: Text(value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
