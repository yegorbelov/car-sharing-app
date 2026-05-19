import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../models/vehicle.dart';
import '../../services/staff_api.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/listing_status_style.dart';
import '../../widgets/moderation_reject_dialog.dart';
import '../catalog/vehicle_detail_screen.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  List<Vehicle> _queue = [];
  List<RejectionReason> _reasons = [];
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
      final queue = await StaffApi.fetchModerationQueue();
      final reasons = await StaffApi.fetchRejectionReasons();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _reasons = reasons;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<bool> _approve(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve listing?'),
        content: Text(
          'Publish “${v.title}” in the catalog. The owner will be notified that the listing is live.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await StaffApi.approveListing(v.id);
      if (!mounted) return false;
      context.showAppSnackBar(
        'Listing approved.',
        kind: AppSnackBarKind.success,
      );
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      context.showAppSnackBar('$e');
      return false;
    }
  }

  Future<bool> _reject(Vehicle v) async {
    if (_reasons.isEmpty) return false;
    final input = await showModerationRejectDialog(
      context,
      vehicle: v,
      reasons: _reasons,
    );
    if (input == null) return false;
    try {
      await StaffApi.rejectListing(
        vehicleId: v.id,
        reasonCode: input.reasonCode,
        note: input.comment,
      );
      if (!mounted) return false;
      context.showAppSnackBar(
        'Listing rejected.',
        kind: AppSnackBarKind.success,
      );
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      context.showAppSnackBar('$e');
      return false;
    }
  }

  Future<void> _openListingReview(Vehicle v) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (detailCtx) => VehicleDetailScreen(
          vehicle: v,
          moderationReview: true,
          onModerationApprove: () async {
            final ok = await _approve(v);
            if (ok && detailCtx.mounted) {
              Navigator.pop(detailCtx, true);
            }
          },
          onModerationReject: () async {
            final ok = await _reject(v);
            if (ok && detailCtx.mounted) {
              Navigator.pop(detailCtx, true);
            }
          },
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Listing moderation'),
            if (!_loading && _error == null)
              Text(
                _queue.isEmpty
                    ? 'Queue empty'
                    : '${_queue.length} awaiting review',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFFF4F6FA),
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, textAlign: TextAlign.center))
          : _queue.isEmpty
          ? const Center(child: Text('No listings awaiting review.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _queue.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final v = _queue[i];
                  final cover = v.photoUrl.isNotEmpty
                      ? fullImageUrl(v.photoUrl)
                      : null;
                  return Material(
                    color: cs.surface,
                    elevation: 0,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openListingReview(v),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: cover != null
                                      ? Image.network(
                                          cover,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: const Color(0xFFF4F6FA),
                                          child: Icon(
                                            Icons.directions_car_rounded,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListingStatusChip(
                                        status: v.listingStatus,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        v.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${v.city} · \$${v.pricePerDay.toStringAsFixed(0)}/day',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        '${v.galleryUrls.length} photos',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _reject(v),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(44),
                                      foregroundColor: cs.error,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton(
                                    onPressed: () => _approve(v),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

