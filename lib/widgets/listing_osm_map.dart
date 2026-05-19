import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap fallback when platform maps are unavailable.
class ListingOsmMap extends StatefulWidget {
  const ListingOsmMap({
    super.key,
    required this.pin,
    required this.onPinChanged,
    this.onMapReady,
  });

  final LatLng pin;
  final ValueChanged<LatLng> onPinChanged;
  final void Function(MapController controller)? onMapReady;

  @override
  State<ListingOsmMap> createState() => _ListingOsmMapState();
}

class _ListingOsmMapState extends State<ListingOsmMap> {
  final _mapController = MapController();
  var _ready = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ListingOsmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin != widget.pin) {
      _moveTo(widget.pin, 14);
    }
  }

  void _onMapReady() {
    _ready = true;
    widget.onMapReady?.call(_mapController);
    _moveTo(widget.pin, 14);
  }

  void _moveTo(LatLng target, double zoom) {
    if (!mounted || !_ready) return;
    _mapController.move(target, zoom);
  }

  void _onTap(TapPosition _, LatLng point) {
    widget.onPinChanged(point);
    _moveTo(point, 14);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.pin,
        initialZoom: 14,
        onMapReady: _onMapReady,
        onTap: _onTap,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.car_sharing_app',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.pin,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: Icon(
                Icons.location_on_rounded,
                size: 44,
                color: cs.primary,
                shadows: const [
                  Shadow(
                    color: Color(0x44000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
