import 'dart:io';

String apiBaseUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:1323';
  }
  return 'http://localhost:1323';
}

/// Converts a server-relative path like /uploads/foo.jpg to a full URL.
String fullImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '${apiBaseUrl()}$path';
}
