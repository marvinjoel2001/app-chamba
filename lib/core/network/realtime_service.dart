import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../session/session_store.dart';
import '../services/toast_service.dart';

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  String? _connectedUserId;

  io.Socket get socket => _socket!;

  bool get isConnected => _socket?.connected == true;

  void connect({String? userId}) {
    final url = '${AppConfig.socketBaseUrl}${AppConfig.socketNamespace}';

    // Si ya hay socket con el mismo userId y está conectado, solo re-emite join
    if (_socket != null && _connectedUserId == userId && _socket!.connected) {
      if (userId != null && userId.isNotEmpty) {
        _socket!.emit('join.user', {'userId': userId});
      }
      return;
    }

    // Si hay socket con distinto userId (cambio de cuenta), lo destruimos
    if (_socket != null && _connectedUserId != userId) {
      _socket!.dispose();
      _socket = null;
      _connectedUserId = null;
    }

    // Crear socket nuevo si no existe
    _socket ??= io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery(userId == null || userId.isEmpty ? {} : {'userId': userId})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _connectedUserId = userId;

    // Siempre re-emitir join.user al reconectar (cubre hot restart y reconexiones)
    if (userId != null && userId.isNotEmpty) {
      // Remover listener previo para no duplicar
      _socket!.off('connect');
      _socket!.on('connect', (_) {
        _socket?.emit('join.user', {'userId': userId});
        if (kDebugMode) {
          print('[RealtimeService] Conectado → join.user $userId');
        }
      });
    }

    // Conectar si no está conectado
    if (!_socket!.connected) {
      _socket!.connect();
    } else if (userId != null && userId.isNotEmpty) {
      // Ya conectado: emitir join inmediatamente
      _socket!.emit('join.user', {'userId': userId});
    }

    if (kDebugMode) {
      _socket!.on(
        'disconnect',
        (reason) => print('[RealtimeService] Socket desconectado: $reason'),
      );
      _socket!.on(
        'connect_error',
        (err) => print('[RealtimeService] Error de conexión: $err'),
      );
      _socket!.on(
        'connection.ready',
        (data) => print('[RealtimeService] connection.ready: $data'),
      );
    }

    _socket!.off('notification.toast');
    _socket!.on('notification.toast', (data) {
      if (data is Map<String, dynamic>) {
        final target = data['target'] as String?;
        final userIds = data['userIds'] as List<dynamic>?;
        final currentUser = SessionStore.currentUser;
        if (currentUser == null) return;

        bool shouldShow = false;
        if (target == 'all') {
          shouldShow = true;
        } else if (target == 'workers' && currentUser.type == 'worker') {
          shouldShow = true;
        } else if (target == 'clients' && currentUser.type == 'client') {
          shouldShow = true;
        } else if (target == 'custom' && userIds != null) {
          if (userIds.contains(currentUser.id)) {
            shouldShow = true;
          }
        }

        if (shouldShow) {
          final typeStr = data['toastType'] as String? ?? 'info';
          ToastType tType;
          switch (typeStr) {
            case 'error':
              tType = ToastType.error;
              break;
            case 'success':
              tType = ToastType.success;
              break;
            default:
              tType = ToastType.info;
              break;
          }

          ToastService.show(
            title: data['title'] as String? ?? 'Notificación',
            body: data['body'] as String? ?? '',
            type: tType,
          );
        }
      }
    });
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
    _connectedUserId = null;
  }
}
