import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

// ignore_for_file: use_build_context_synchronously

import '../../core/api_config.dart';
import '../../core/auth_storage.dart';
import '../../models/vehicle.dart';
import '../../services/deals_api.dart';
import '../../services/vehicles_api.dart';
import '../auth/login_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
    this.onSignedIn,
  });

  final Vehicle vehicle;

  /// Called after a guest successfully signs in from this screen.
  final VoidCallback? onSignedIn;

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
    if (_vehicle.galleryUrls.length >= 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This listing already has 10 photos.')),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final r = await VehiclesApi.uploadVehiclePhoto(
        vehicleId: _vehicle.id,
        filePath: picked.path,
      );
      if (!mounted) return;
      setState(() {
        _vehicle = _vehicle.copyWith(
          photoUrl: r.photoUrl,
          photoUrls: r.photoUrls,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => _SignInPromptSheet(
          message: 'Sign in to rent this car',
          onSignIn: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
      );
      if (proceed != true || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onSignedIn: () {
              Navigator.of(context).pop();
              widget.onSignedIn?.call();
            },
          ),
        ),
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
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v.title,
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Duration',
                            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$days ${days == 1 ? 'day' : 'days'}',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Security hold',
                            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '\$$total',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                          ),
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
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
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
        'vehicle_unavailable' =>
          'This car already has an active or pending booking.',
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
              background: _VehicleHero(
                key: ValueKey(v.galleryUrls.join('|')),
                vehicle: v,
                uploading: _uploadingPhoto,
              ),
            ),
            actions: [
              if (isOwner)
                IconButton(
                  onPressed: v.galleryUrls.length >= 10
                      ? null
                      : _pickAndUploadPhoto,
                  icon: const Icon(Icons.add_a_photo_rounded),
                  tooltip: v.galleryUrls.length >= 10
                      ? 'Max 10 photos'
                      : 'Add photo',
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\$${v.pricePerDay.toStringAsFixed(0)}/day',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SvgPicture.asset('assets/icons/star.svg', width: 18, height: 18),
                    const SizedBox(width: 5),
                    Text(
                      v.rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      v.city,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _VehicleSpecsCard(vehicle: v),

                const SizedBox(height: 16),

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
                          value:
                              '\$${v.pricePerDay.toStringAsFixed(0)} × trip days',
                        ),
                        const Divider(),
                        _DetailTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Rate',
                          value:
                              '\$${v.pricePerDay.toStringAsFixed(2)} per day',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                if (isOwner)
                  OutlinedButton.icon(
                    onPressed: v.galleryUrls.length >= 10
                        ? null
                        : _pickAndUploadPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      v.galleryUrls.length >= 10
                          ? 'Max 10 photos'
                          : (v.galleryUrls.isEmpty
                                ? 'Add photos'
                                : 'Add another photo'),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _openBookSheet,
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
}

class _VehicleHero extends StatefulWidget {
  const _VehicleHero({
    super.key,
    required this.vehicle,
    required this.uploading,
  });

  final Vehicle vehicle;
  final bool uploading;

  @override
  State<_VehicleHero> createState() => _VehicleHeroState();
}

class _VehicleHeroState extends State<_VehicleHero> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _VehicleHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.vehicle.galleryUrls.length;
    if (n > 0 && _pageIndex >= n) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urls = widget.vehicle.galleryUrls.map(fullImageUrl).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (urls.isEmpty)
          _heroPlaceholder(cs)
        else if (urls.length == 1)
          Image.network(
            urls.first,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _heroPlaceholder(cs),
          )
        else
          PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, i) => Image.network(
              urls[i],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => _heroPlaceholder(cs),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        if (widget.uploading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }

  Widget _heroPlaceholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 90,
          color: cs.onPrimaryContainer.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _VehicleSpecsCard extends StatelessWidget {
  const _VehicleSpecsCard({required this.vehicle});

  final Vehicle vehicle;

  static String _transmissionLabel(String c) => switch (c.toLowerCase()) {
    'automatic' => 'Automatic',
    'manual' => 'Manual',
    'cvt' => 'CVT',
    'other' => 'Other',
    _ => c,
  };

  static String _fuelLabel(String c) => switch (c.toLowerCase()) {
    'petrol' => 'Petrol',
    'diesel' => 'Diesel',
    'electric' => 'Electric',
    'hybrid' => 'Hybrid',
    'lpg' => 'LPG',
    'other' => 'Other',
    _ => c,
  };

  static String _drivetrainLabel(String c) => switch (c.toLowerCase()) {
    'fwd' => 'FWD',
    'rwd' => 'RWD',
    'awd' => 'AWD',
    'other' => 'Other',
    _ => c,
  };

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final rows = <Widget>[];

    void pushTile(IconData icon, String label, String value) {
      if (value.isEmpty) return;
      if (rows.isNotEmpty) rows.add(const Divider(height: 1));
      rows.add(_DetailTile(icon: icon, label: label, value: value));
    }

    if (v.mileageKm > 0) {
      pushTile(Icons.speed_outlined, 'Mileage', '${v.mileageKm} km');
    }
    if (v.modelYear > 0) {
      pushTile(Icons.calendar_today_outlined, 'Year', '${v.modelYear}');
    }
    if (v.transmission.isNotEmpty) {
      pushTile(
        Icons.settings_outlined,
        'Transmission',
        _transmissionLabel(v.transmission),
      );
    }
    if (v.fuelType.isNotEmpty) {
      pushTile(
        Icons.local_gas_station_outlined,
        'Fuel',
        _fuelLabel(v.fuelType),
      );
    }
    if (v.drivetrain.isNotEmpty) {
      pushTile(
        Icons.all_inclusive,
        'Drivetrain',
        _drivetrainLabel(v.drivetrain),
      );
    }
    if (v.engineCc > 0) {
      pushTile(Icons.engineering_outlined, 'Engine', '${v.engineCc} cc');
    }
    if (v.exteriorColor.isNotEmpty) {
      pushTile(Icons.palette_outlined, 'Color', v.exteriorColor);
    }
    if (v.vin.isNotEmpty) {
      pushTile(Icons.tag_outlined, 'VIN', v.vin);
    }

    final hasListTiles = rows.isNotEmpty;
    final hasNotes = v.conditionSummary.isNotEmpty || v.techNotes.isNotEmpty;
    if (!hasListTiles && !hasNotes) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasListTiles) ...rows,
            if (v.conditionSummary.isNotEmpty) ...[
              if (hasListTiles) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Condition',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  v.conditionSummary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (v.techNotes.isNotEmpty) ...[
              if (hasListTiles || v.conditionSummary.isNotEmpty)
                const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Technical notes',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  v.techNotes,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignInPromptSheet extends StatelessWidget {
  const _SignInPromptSheet({
    required this.message,
    required this.onSignIn,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onSignIn;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a free account to book cars and manage your rentals.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 20, color: cs.primary),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
