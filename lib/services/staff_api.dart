import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/auth_storage.dart';
import '../models/dispute.dart';
import '../models/vehicle.dart';
import 'auth_api.dart';

class StaffUser {
  const StaffUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isAdmin,
    required this.isModerator,
    required this.isArbitrator,
    required this.roles,
  });

  final int id;
  final String email;
  final String fullName;
  final bool isAdmin;
  final bool isModerator;
  final bool isArbitrator;
  final List<String> roles;

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
    id: (j['id'] as num).toInt(),
    email: j['email'] as String,
    fullName: (j['fullName'] as String?) ?? '',
    isAdmin: j['isAdmin'] as bool? ?? false,
    isModerator: j['isModerator'] as bool? ?? false,
    isArbitrator: j['isArbitrator'] as bool? ?? false,
    roles: (j['roles'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );
}

class RejectionReason {
  const RejectionReason({required this.code, required this.label});

  final String code;
  final String label;

  factory RejectionReason.fromJson(Map<String, dynamic> j) => RejectionReason(
    code: j['code'] as String,
    label: j['label'] as String,
  );
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.createdAt,
  });

  final int id;
  final String actorName;
  final String action;
  final String entityType;
  final int entityId;
  final String details;
  final String createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
    id: (j['id'] as num).toInt(),
    actorName: (j['actorName'] as String?) ?? '',
    action: j['action'] as String,
    entityType: j['entityType'] as String,
    entityId: (j['entityId'] as num).toInt(),
    details: (j['details'] as String?) ?? '',
    createdAt: (j['createdAt'] as String?) ?? '',
  );
}

class StaffApi {
  static Never _checkResponse(http.Response res) {
    if (res.statusCode == 401) {
      AuthApi.onUnauthorized?.call();
      throw AuthApiException(401, 'session_expired');
    }
    throw AuthApiException(res.statusCode, res.body);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) throw StateError('not_signed_in');
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Vehicle>> fetchModerationQueue() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/moderation/vehicles');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<RejectionReason>> fetchRejectionReasons() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/moderation/rejection-reasons');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => RejectionReason.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> approveListing(int vehicleId) async {
    final uri = Uri.parse(
      '${apiBaseUrl()}/api/v1/moderation/vehicles/$vehicleId/approve',
    );
    final res = await http.post(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
  }

  static Future<void> rejectListing({
    required int vehicleId,
    required String reasonCode,
    String note = '',
  }) async {
    final uri = Uri.parse(
      '${apiBaseUrl()}/api/v1/moderation/vehicles/$vehicleId/reject',
    );
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'reasonCode': reasonCode, 'note': note}),
    );
    if (res.statusCode != 200) _checkResponse(res);
  }

  static Future<List<StaffUser>> fetchUsers() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/admin/users');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => StaffUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<StaffUser> updateUserRoles({
    required int userId,
    bool? isAdmin,
    bool? isModerator,
    bool? isArbitrator,
  }) async {
    final body = <String, dynamic>{};
    if (isAdmin != null) body['isAdmin'] = isAdmin;
    if (isModerator != null) body['isModerator'] = isModerator;
    if (isArbitrator != null) body['isArbitrator'] = isArbitrator;
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/admin/users/$userId/roles');
    final res = await http.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) _checkResponse(res);
    return StaffUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<List<AuditLogEntry>> fetchAuditLog() async {
    final uri = Uri.parse('${apiBaseUrl()}/api/v1/admin/audit-log');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<RentalDispute>> fetchArbitrationQueue({
    String status = 'open',
  }) async {
    final uri = Uri.parse(
      '${apiBaseUrl()}/api/v1/arbitration/disputes?status=$status',
    );
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => RentalDispute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RentalDispute> fetchArbitrationDispute(int disputeId) async {
    final uri = Uri.parse(
      '${apiBaseUrl()}/api/v1/arbitration/disputes/$disputeId',
    );
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) _checkResponse(res);
    return RentalDispute.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<RentalDispute> resolveDispute({
    required int disputeId,
    required String resolution,
    int? renterRefundCents,
    int? ownerPayoutCents,
    String note = '',
  }) async {
    final body = <String, dynamic>{
      'resolution': resolution,
      'note': note,
    };
    if (renterRefundCents != null) {
      body['renterRefundCents'] = renterRefundCents;
    }
    if (ownerPayoutCents != null) {
      body['ownerPayoutCents'] = ownerPayoutCents;
    }
    final uri = Uri.parse(
      '${apiBaseUrl()}/api/v1/arbitration/disputes/$disputeId/resolve',
    );
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) _checkResponse(res);
    return RentalDispute.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
