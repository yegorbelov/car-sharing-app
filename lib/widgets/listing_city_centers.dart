import 'package:latlong2/latlong.dart';

/// Default map centers for cities in [ListingFormSuggestions.defaultCities].
abstract final class ListingCityCenters {
  static LatLng? forCity(String city) {
    final key = city.trim().toLowerCase();
    return switch (key) {
      'moscow' => const LatLng(55.7558, 37.6173),
      'saint petersburg' => const LatLng(59.9343, 30.3351),
      'kazan' => const LatLng(55.7961, 49.1064),
      'sochi' => const LatLng(43.6028, 39.7342),
      'nizhny novgorod' => const LatLng(56.2965, 43.9361),
      'yekaterinburg' => const LatLng(56.8389, 60.6057),
      'novosibirsk' => const LatLng(55.0084, 82.9357),
      'krasnodar' => const LatLng(45.0355, 38.9753),
      _ => null,
    };
  }

  static LatLng resolve({
    double? latitude,
    double? longitude,
    required String city,
    LatLng fallback = const LatLng(55.7558, 37.6173),
  }) {
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }
    return forCity(city) ?? fallback;
  }
}
