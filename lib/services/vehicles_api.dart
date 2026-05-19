import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/auth_storage.dart';
import '../models/vehicle_review.dart';

class VehiclePhotoUploadResult {
  const VehiclePhotoUploadResult({required this.photoUrl, required this.photoUrls});

  final String photoUrl;
  final List<String> photoUrls;

  factory VehiclePhotoUploadResult.fromJson(Map<String, dynamic> j) {
    final raw = j['photoUrls'];
    var urls = <String>[];
    if (raw is List) {
      urls = raw.map((e) => e.toString()).toList();
    }
    return VehiclePhotoUploadResult(
      photoUrl: (j['photoUrl'] as String?) ?? '',
      photoUrls: urls,
    );
  }
}

class VehiclesApi {
  VehiclesApi._();

  static void Function()? onUnauthorized;

  static Never _throwIfUnauthorized(http.Response res) {
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw StateError('session_expired');
    }
    throw Exception(_errorMessage(res));
  }

  static String _errorMessage(http.Response res) {
    String msg = res.body;
    try {
      final m = jsonDecode(res.body);
      if (m is Map && m['error'] is String) msg = m['error'] as String;
    } catch (_) {}
    return msg;
  }

  static Future<List<VehicleReview>> fetchReviews(int vehicleId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/vehicles/$vehicleId/reviews');
    final res = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (res.statusCode == 404) return [];
    if (res.statusCode != 200) {
      throw Exception('reviews ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => VehicleReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchRaw() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/vehicles');
    final res = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('vehicles ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createListing({
    required String title,
    required String city,
    required String className,
    required double pricePerDay,
    double? rating,
    required int mileageKm,
    required int modelYear,
    required String transmission,
    required String fuelType,
    required String drivetrain,
    required int engineCc,
    required String exteriorColor,
    required String conditionSummary,
    required String techNotes,
    required String vin,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) throw StateError('not_signed_in');

    final uri = Uri.parse('${apiBaseUrl()}/api/v1/vehicles');
    final body = <String, dynamic>{
      'title': title.trim(),
      'city': city.trim(),
      'class': className.trim(),
      'pricePerDay': pricePerDay,
      'mileageKm': mileageKm,
      'modelYear': modelYear,
      'transmission': transmission.trim().toLowerCase(),
      'fuelType': fuelType.trim().toLowerCase(),
      'drivetrain': drivetrain.trim().toLowerCase(),
      'engineCc': engineCc,
      'exteriorColor': exteriorColor.trim(),
      'conditionSummary': conditionSummary.trim(),
      'techNotes': techNotes.trim(),
      'vin': vin.trim().toUpperCase(),
    };
    if (rating != null) body['rating'] = rating;

    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) _throwIfUnauthorized(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Append a photo for a vehicle (owner only, max 10). Returns updated gallery.
  static Future<VehiclePhotoUploadResult> uploadVehiclePhoto({
    required int vehicleId,
    required String filePath,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) throw StateError('not_signed_in');

    final uri = Uri.parse('${apiBaseUrl()}/api/v1/vehicles/$vehicleId/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) _throwIfUnauthorized(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return VehiclePhotoUploadResult.fromJson(body);
  }
}
