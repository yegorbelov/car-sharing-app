import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/auth_storage.dart';
import '../models/rental_deal.dart';

class DealsApiException implements Exception {
  DealsApiException(this.statusCode, this.code);
  final int statusCode;
  final String code;
  @override
  String toString() => code;
}

class DealsApi {
  DealsApi._();

  /// Called when any request gets a 401 — use to trigger global sign-out.
  static void Function()? onUnauthorized;

  static Future<Map<String, String>> _authHeaders() async {
    final t = await AuthStorage.getToken();
    if (t == null || t.isEmpty) {
      throw StateError('not_signed_in');
    }
    return {
      'Authorization': 'Bearer $t',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  static String _parseError(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] is String) return m['error'] as String;
    } catch (_) {}
    return body;
  }

  static Never _throwOrUnauthorized(http.Response res) {
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw DealsApiException(401, 'session_expired');
    }
    throw DealsApiException(res.statusCode, _parseError(res.body));
  }

  static Future<List<RentalDeal>> fetchMine() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/mine');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => RentalDeal.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<RentalDeal> fetchDeal(int id) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$id');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
    return RentalDeal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<List<DealMessage>> fetchMessages(int dealId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$dealId/messages');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => DealMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DealMessage> postMessage(int dealId, String body) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$dealId/messages');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'body': body}),
    );
    if (res.statusCode != 201) _throwOrUnauthorized(res);
    return DealMessage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> createDeal({required int vehicleId, int dayCount = 3}) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'vehicleId': vehicleId, 'dayCount': dayCount}),
    );
    if (res.statusCode != 201) _throwOrUnauthorized(res);
  }

  static Future<void> accept(int dealId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$dealId/accept');
    final res = await http.post(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
  }

  static Future<void> decline(int dealId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$dealId/decline');
    final res = await http.post(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
  }

  static Future<void> renterCancel(int dealId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$dealId/cancel');
    final res = await http.post(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
  }

  static Future<void> complete(int dealId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/deals/$dealId/complete');
    final res = await http.post(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
  }

  static Future<WalletData> fetchWallet() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/wallet');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) _throwOrUnauthorized(res);
    return WalletData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
