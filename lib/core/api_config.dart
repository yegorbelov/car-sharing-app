import 'dart:io';

String apiBaseUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:1323';
  }
  return 'http://localhost:1323';
}
