import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/auth_storage.dart';

class VehiclesApi {
  VehiclesApi._();

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
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('not_signed_in');
    }
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/vehicles');
    final body = <String, dynamic>{
      'title': title.trim(),
      'city': city.trim(),
      'class': className.trim(),
      'pricePerDay': pricePerDay,
    };
    if (rating != null) {
      body['rating'] = rating;
    }
    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) {
      String msg = res.body;
      try {
        final m = jsonDecode(res.body);
        if (m is Map && m['error'] is String) msg = m['error'] as String;
      } catch (_) {}
      throw Exception(msg);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
