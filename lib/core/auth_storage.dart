import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';

const _kToken = 'auth_access_token';
const _kUserJson = 'auth_user_json';

class AuthStorage {
  AuthStorage._();

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  static Future<AuthUser?> getUser() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kUserJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSession({
    required String accessToken,
    required AuthUser user,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, accessToken);
    await p.setString(_kUserJson, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUserJson);
  }

  static Future<bool> hasSession() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }
}
