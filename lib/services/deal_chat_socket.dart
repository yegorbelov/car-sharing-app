import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api_config.dart';
import '../core/auth_storage.dart';

/// Live updates for deal chat via WebSocket (replaces polling).
class DealChatSocket {
  DealChatSocket({
    required this.dealId,
    required this.onNewMessage,
    this.onUnauthorized,
  });

  final int dealId;
  final void Function() onNewMessage;
  final void Function()? onUnauthorized;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connecting = false;

  void connect() {
    if (_disposed || _connecting) return;
    _connecting = true;
    unawaited(_open());
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_closeChannel());
  }

  Future<void> _open() async {
    _reconnectTimer?.cancel();
    await _closeChannel();

    if (_disposed) {
      _connecting = false;
      return;
    }

    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        onUnauthorized?.call();
        return;
      }

      final uri = dealChatWebSocketUri(dealId, token);
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      _channel = channel;
      _subscription = channel.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onData(dynamic data) {
    try {
      final raw = data is String ? data : utf8.decode(data as List<int>);
      final json = jsonDecode(raw);
      if (json is! Map) return;
      if (json['type'] == 'new_message') {
        onNewMessage();
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    unawaited(_closeChannel());
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed) connect();
    });
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
