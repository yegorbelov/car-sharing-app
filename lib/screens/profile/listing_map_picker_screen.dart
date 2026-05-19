import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/listing_city_centers.dart';
import '../../widgets/listing_platform_map.dart';

class MapPickResult {
  const MapPickResult({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Full-screen map to choose a pickup point.
class ListingMapPickerScreen extends StatefulWidget {
  const ListingMapPickerScreen({
    super.key,
    required this.city,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String city;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<ListingMapPickerScreen> createState() => _ListingMapPickerScreenState();
}

class _ListingMapPickerScreenState extends State<ListingMapPickerScreen> {
  late LatLng _pin;
  ListingMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _pin = ListingCityCenters.resolve(
      latitude: widget.initialLatitude,
      longitude: widget.initialLongitude,
      city: widget.city,
    );
  }

  void _centerOnCity() {
    final center = ListingCityCenters.forCity(widget.city);
    if (center == null) return;
    setState(() => _pin = center);
    _mapController?.moveTo(center, zoom: 12);
  }

  void _confirm() {
    Navigator.pop(
      context,
      MapPickResult(latitude: _pin.latitude, longitude: _pin.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCityCenter = ListingCityCenters.forCity(widget.city) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup location'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Done'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListingPlatformMap(
            pin: _pin,
            onPinChanged: (point) => setState(() => _pin = point),
            onControllerReady: (controller) => _mapController = controller,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Material(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  color: cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_pin.latitude.toStringAsFixed(5)}, '
                            '${_pin.longitude.toStringAsFixed(5)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (hasCityCenter)
                          TextButton(
                            onPressed: _centerOnCity,
                            child: const Text('City'),
                          ),
                      ],
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
