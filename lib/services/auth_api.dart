import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/auth_user.dart';

class AuthApiException implements Exception {
  AuthApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class AuthApi {
  AuthApi._();

  static Map<String, String> _jsonHeaders([String? bearer]) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (bearer != null && bearer.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearer';
    }
    return h;
  }

  static String _errBody(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] is String) return m['error'] as String;
    } catch (_) {}
    return body;
  }

  static Future<({String token, AuthUser user})> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/auth/register');
    final res = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
      }),
    );
    if (res.statusCode != 201) {
      throw AuthApiException(res.statusCode, _errBody(res.body));
    }
    return _parseAuth(res.body);
  }

  static Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/auth/login');
    final res = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );
    if (res.statusCode != 200) {
      throw AuthApiException(res.statusCode, _errBody(res.body));
    }
    return _parseAuth(res.body);
  }

  static Future<AuthUser> fetchMe(String token) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/auth/me');
    final res = await http.get(uri, headers: _jsonHeaders(token));
    if (res.statusCode != 200) {
      throw AuthApiException(res.statusCode, _errBody(res.body));
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final u = map['user'] as Map<String, dynamic>?;
    if (u == null) {
      throw AuthApiException(res.statusCode, 'invalid_response');
    }
    return AuthUser.fromJson(u);
  }

  static ({String token, AuthUser user}) _parseAuth(String body) {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final token = map['accessToken'] as String?;
    final userMap = map['user'] as Map<String, dynamic>?;
    if (token == null || userMap == null) {
      throw AuthApiException(500, 'invalid_response');
    }
    return (token: token, user: AuthUser.fromJson(userMap));
  }
}
