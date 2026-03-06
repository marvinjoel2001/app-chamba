import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

class RealtimeService {
  io.Socket? _socket;

  void connect() {
    _socket ??= io.io(
      '${AppConfig.socketBaseUrl}${AppConfig.socketNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    if (!(_socket!.connected)) {
      _socket!.connect();
    }
  }

  void onUserCreated(void Function(dynamic payload) handler) {
    _socket?.on('user.created', handler);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
