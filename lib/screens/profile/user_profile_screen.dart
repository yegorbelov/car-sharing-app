import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api_config.dart';
import '../../widgets/completed_trips_label.dart';
import '../../models/user_profile.dart';
import '../../models/vehicle.dart';
import '../../services/users_api.dart';
import '../catalog/vehicle_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await UsersApi.fetchProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
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

  void _openVehicle(Vehicle vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(vehicle: vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFF4F6FA),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _ProfileBody(
              profile: _profile!,
              onOpenVehicle: _openVehicle,
            ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.onOpenVehicle,
  });

  final UserProfile profile;
  final ValueChanged<Vehicle> onOpenVehicle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final avatarUrl = profile.avatarUrl.isNotEmpty
        ? fullImageUrl(profile.avatarUrl)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          profile.initials,
                          style: tt.headlineSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.fullName,
                  textAlign: TextAlign.center,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.memberSinceLabel,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (profile.hasRating) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/star.svg',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        profile.rating.toStringAsFixed(1),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        profile.reviewCount == 1
                            ? '1 review'
                            : '${profile.reviewCount} reviews',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (profile.isHost) _RoleBadge.host(),
                    if (profile.isRenter) _RoleBadge.renter(),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (profile.isHost) ...[
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Listings',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.listings.isEmpty
                        ? 'No published cars yet.'
                        : 'Cars this host offers for rent.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  if (profile.listings.isEmpty) ...[
                    const SizedBox(height: 20),
                    Icon(
                      Icons.directions_car_outlined,
                      size: 40,
                      color: cs.outline.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          ...profile.listings.map(
            (v) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _HostListingTile(
                vehicle: v,
                onTap: () => onOpenVehicle(v),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HostListingTile extends StatelessWidget {
  const _HostListingTile({required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cover = vehicle.photoUrl.isNotEmpty
        ? fullImageUrl(vehicle.photoUrl)
        : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 118,
                child: cover != null
                    ? ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Image.network(
                          cover,
                          fit: BoxFit.cover,
                          width: 118,
                          height: 104,
                          errorBuilder: (_, _, _) => _placeholder(cs),
                        ),
                      )
                    : _placeholder(cs),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        vehicle.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (vehicle.completedTrips > 0) ...[
                        const SizedBox(height: 6),
                        CompletedTripsLabel(
                          count: vehicle.completedTrips,
                          compact: true,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              vehicle.catalogLocationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '\$${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 36,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge._({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  _RoleBadge.host()
      : this._(
          label: 'Host',
          icon: Icons.garage_rounded,
          bg: const Color(0xFFE3F2FD),
          fg: const Color(0xFF1565C0),
        );

  _RoleBadge.renter()
      : this._(
          label: 'Renter',
          icon: Icons.directions_car_rounded,
          bg: const Color(0xFFF3E5F5),
          fg: const Color(0xFF7B1FA2),
        );

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
