import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;

  io.Socket get socket => _socket!;

  void connect({String? userId}) {
    _socket ??= io.io(
      '${AppConfig.socketBaseUrl}${AppConfig.socketNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery(userId == null || userId.isEmpty ? {} : {'userId': userId})
          .disableAutoConnect()
          .build(),
    );

    if (!(_socket!.connected)) {
      _socket!.connect();
    }

    if (userId != null && userId.isNotEmpty) {
      _socket!.emit('join.user', {'userId': userId});
    }
  }

  void joinThread(String threadId) {
    if (threadId.trim().isEmpty) {
      return;
    }
    _socket?.emit('join.thread', {'threadId': threadId});
  }

  void on(String event, void Function(dynamic payload) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic payload)? handler]) {
    if (handler == null) {
      _socket?.off(event);
      return;
    }
    _socket?.off(event, handler);
  }

  void onUserCreated(void Function(dynamic payload) handler) {
    _socket?.on('user.created', handler);
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
