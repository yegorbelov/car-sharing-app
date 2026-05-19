import 'dart:io' show Platform;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';

import '../core/maps_config.dart';
import 'listing_osm_map.dart';

/// Map view that uses Apple Maps on iOS, Google Maps on Android when configured,
/// and OpenStreetMap elsewhere.
class ListingPlatformMap extends StatefulWidget {
  const ListingPlatformMap({
    super.key,
    required this.pin,
    required this.onPinChanged,
    this.onControllerReady,
  });

  final LatLng pin;
  final ValueChanged<LatLng> onPinChanged;
  final void Function(ListingMapController controller)? onControllerReady;

  @override
  State<ListingPlatformMap> createState() => _ListingPlatformMapState();
}

/// Moves the map camera to a coordinate.
abstract interface class ListingMapController {
  void moveTo(LatLng target, {double zoom = 14});
}

class _ListingPlatformMapState extends State<ListingPlatformMap>
    implements ListingMapController {
  google.GoogleMapController? _googleController;
  apple.AppleMapController? _appleController;

  @override
  void moveTo(LatLng target, {double zoom = 14}) {
    if (!mounted) return;
    if (_appleController != null) {
      _appleController!.moveCamera(
        apple.CameraUpdate.newCameraPosition(
          apple.CameraPosition(
            target: apple.LatLng(target.latitude, target.longitude),
            zoom: zoom,
          ),
        ),
      );
      return;
    }
    _googleController?.animateCamera(
      google.CameraUpdate.newCameraPosition(
        google.CameraPosition(
          target: google.LatLng(target.latitude, target.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(ListingPlatformMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin != widget.pin) {
      moveTo(widget.pin);
    }
  }

  bool get _useAppleMap => !kIsWeb && Platform.isIOS;

  bool get _useGoogleMap =>
      !kIsWeb && Platform.isAndroid && googleMapsApiKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_useAppleMap) {
      return _AppleMapBody(
        pin: widget.pin,
        onPinChanged: widget.onPinChanged,
        onCreated: (c) {
          _appleController = c;
          widget.onControllerReady?.call(this);
        },
      );
    }
    if (_useGoogleMap) {
      return _GoogleMapBody(
        pin: widget.pin,
        onPinChanged: widget.onPinChanged,
        onCreated: (c) {
          _googleController = c;
          widget.onControllerReady?.call(this);
        },
      );
    }
    return ListingOsmMap(
      pin: widget.pin,
      onPinChanged: widget.onPinChanged,
      onMapReady: (controller) {
        widget.onControllerReady?.call(_OsmListingMapController(controller));
      },
    );
  }
}

class _OsmListingMapController implements ListingMapController {
  _OsmListingMapController(this._controller);

  final dynamic _controller;

  @override
  void moveTo(LatLng target, {double zoom = 14}) {
    _controller.move(target, zoom);
  }
}

class _AppleMapBody extends StatelessWidget {
  const _AppleMapBody({
    required this.pin,
    required this.onPinChanged,
    required this.onCreated,
  });

  final LatLng pin;
  final ValueChanged<LatLng> onPinChanged;
  final ValueChanged<apple.AppleMapController> onCreated;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = apple.LatLng(pin.latitude, pin.longitude);

    return apple.AppleMap(
      initialCameraPosition: apple.CameraPosition(target: target, zoom: 14),
      onMapCreated: onCreated,
      onTap: (point) => onPinChanged(LatLng(point.latitude, point.longitude)),
      annotations: {
        apple.Annotation(
          annotationId: apple.AnnotationId('pickup'),
          position: target,
          icon: apple.BitmapDescriptor.defaultAnnotationWithHue(
            _hueFromColor(cs.primary),
          ),
        ),
      },
    );
  }

  double _hueFromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.hue;
  }
}

class _GoogleMapBody extends StatefulWidget {
  const _GoogleMapBody({
    required this.pin,
    required this.onPinChanged,
    required this.onCreated,
  });

  final LatLng pin;
  final ValueChanged<LatLng> onPinChanged;
  final ValueChanged<google.GoogleMapController> onCreated;

  @override
  State<_GoogleMapBody> createState() => _GoogleMapBodyState();
}

class _GoogleMapBodyState extends State<_GoogleMapBody> {
  @override
  Widget build(BuildContext context) {
    final target = google.LatLng(widget.pin.latitude, widget.pin.longitude);

    return google.GoogleMap(
      initialCameraPosition: google.CameraPosition(target: target, zoom: 14),
      onMapCreated: widget.onCreated,
      onTap: (point) =>
          widget.onPinChanged(LatLng(point.latitude, point.longitude)),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        google.Marker(
          markerId: const google.MarkerId('pickup'),
          position: target,
        ),
      },
    );
  }
}
