import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/user_profile.dart';

class UsersApi {
  UsersApi._();

  static Future<UserProfile> fetchProfile(int userId) async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/users/$userId/profile');
    final res = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (res.statusCode == 404) {
      throw Exception('Profile not found');
    }
    if (res.statusCode != 200) {
      throw Exception('profile ${res.statusCode}');
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
