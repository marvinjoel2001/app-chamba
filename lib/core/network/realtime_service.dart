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

  /// Threads a los que el usuario se unió; se re-emite el join al reconectar
  /// para no perder mensajes en tiempo real tras una caída de conexión.
  final Set<String> _joinedThreadIds = {};

  /// Estado de conexión del socket, útil para mostrar avisos en UI.
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

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
      _joinedThreadIds.clear();
    }

    // Crear socket nuevo si no existe
    _socket ??= io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery(userId == null || userId.isEmpty ? {} : {'userId': userId})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(1 << 30) // reintentar siempre
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .build(),
    );

    _connectedUserId = userId;

    // Siempre re-emitir join.user y join.thread al (re)conectar
    // (cubre hot restart, reconexiones y caídas de red).
    _socket!.off('connect');
    _socket!.on('connect', (_) {
      isConnectedNotifier.value = true;
      if (userId != null && userId.isNotEmpty) {
        _socket?.emit('join.user', {'userId': userId});
      }
      for (final threadId in _joinedThreadIds) {
        _socket?.emit('join.thread', {'threadId': threadId});
      }
      if (kDebugMode) {
        print('[RealtimeService] Conectado → join.user $userId');
      }
    });

    _socket!.off('disconnect', _onDisconnect);
    _socket!.on('disconnect', _onDisconnect);

    if (kDebugMode) {
      _socket!.off('connect_error', _onConnectErrorDebug);
      _socket!.on('connect_error', _onConnectErrorDebug);
    }

    // Conectar si no está conectado
    if (!_socket!.connected) {
      _socket!.connect();
    } else if (userId != null && userId.isNotEmpty) {
      isConnectedNotifier.value = true;
      // Ya conectado: emitir join inmediatamente
      _socket!.emit('join.user', {'userId': userId});
    }

    _socket!.off('notification.toast');
    _socket!.on('notification.toast', _onNotificationToast);
  }

  void _onDisconnect(dynamic reason) {
    isConnectedNotifier.value = false;
    if (kDebugMode) {
      print('[RealtimeService] Socket desconectado: $reason');
    }
  }

  void _onConnectErrorDebug(dynamic err) {
    if (kDebugMode) {
      print('[RealtimeService] Error de conexión: $err');
    }
  }

  void _onNotificationToast(dynamic data) {
    // Normalizar: el payload puede llegar como Map<dynamic, dynamic>.
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);

    final target = map['target'] as String?;
    final userIds = map['userIds'] as List<dynamic>?;
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

    if (!shouldShow) return;

    final typeStr = map['toastType'] as String? ?? 'info';
    final ToastType tType;
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
      title: map['title'] as String? ?? 'Notificación',
      body: map['body'] as String? ?? '',
      type: tType,
    );
  }

  void joinThread(String threadId) {
    final normalized = threadId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _joinedThreadIds.add(normalized);
    _socket?.emit('join.thread', {'threadId': normalized});
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
    isConnectedNotifier.value = false;
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _connectedUserId = null;
    _joinedThreadIds.clear();
    isConnectedNotifier.value = false;
  }
}
