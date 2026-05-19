import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/auth_storage.dart';
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

  static Future<AuthUser> updateProfile({required String fullName}) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) throw StateError('not_signed_in');

    final uri = Uri.parse('${apiBaseUrl()}/api/v1/auth/me');
    final res = await http.patch(
      uri,
      headers: _jsonHeaders(token),
      body: jsonEncode({'fullName': fullName.trim()}),
    );
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

  /// Upload a new avatar for the current user. Returns the updated user.
  static Future<String> uploadAvatar(String filePath) async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) throw StateError('not_signed_in');

    final uri = Uri.parse('${apiBaseUrl()}/api/v1/auth/avatar');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw AuthApiException(res.statusCode, _errBody(res.body));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['avatarUrl'] as String?) ?? '';
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
