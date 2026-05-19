import 'dart:io';

/// Override at build/run time:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.105:1323`
const _apiBaseFromDefine = String.fromEnvironment('API_BASE_URL');

String apiBaseUrl() {
  if (_apiBaseFromDefine.isNotEmpty) return _apiBaseFromDefine;
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:1323';
  }
  // return 'http://127.0.0.1:1323';
  return 'http://192.168.1.105:1323';
}

/// WebSocket URL for live deal chat (`http` → `ws`, `https` → `wss`).
Uri dealChatWebSocketUri(int dealId, String token) {
  final http = Uri.parse(apiBaseUrl());
  final scheme = http.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: scheme,
    host: http.host,
    port: http.hasPort ? http.port : null,
    path: '/api/v1/deals/$dealId/messages/ws',
    queryParameters: {'token': token},
  );
}

/// Converts a server-relative path like /uploads/foo.jpg to a full URL.
String fullImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '${apiBaseUrl()}$path';
}
