import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../session/session_credentials.dart';
import '../push/push_notification_service.dart';
import '../session/unread_messages_notifier.dart';
import '../session/unread_notifications_notifier.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../session/session_store.dart';
import '../services/toast_service.dart';

class RealtimeService with WidgetsBindingObserver {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  String? _connectedUserId;

  /// Threads a los que el usuario se unió; se re-emite el join al reconectar
  /// para no perder mensajes en tiempo real tras una caída de conexión.
  final Set<String> _joinedThreadIds = {};

  /// Estado de conexión del socket, útil para mostrar avisos en UI.
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

  /// true mientras el socket se cayó y está intentando volver (no cuando se
  /// desconectó a propósito por logout). Lo usa el banner de conexión.
  final ValueNotifier<bool> isReconnecting = ValueNotifier<bool>(false);

  /// Se incrementa en cada RE-conexión (no en la primera). Los eventos
  /// emitidos por el backend mientras el socket estaba caído se pierden, así
  /// que las pantallas con estado vivo (solicitud, tracking, trabajo en curso,
  /// chat) escuchan este contador y vuelven a consultar al backend.
  final ValueNotifier<int> reconnectCount = ValueNotifier<int>(0);

  bool _hasConnectedOnce = false;
  Timer? _presenceTimer;
  bool _observing = false;

  io.Socket get socket => _socket!;

  bool get isConnected => _socket?.connected == true;

  void connect({String? userId}) {
    if (SessionCredentials.accessToken == null) return;
    if (!_observing) { WidgetsBinding.instance.addObserver(this); _observing = true; }
    _presenceTimer ??= Timer.periodic(const Duration(seconds: 20), (_) => updatePresence());
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
      _hasConnectedOnce = false;
      isReconnecting.value = false;
    }

    // Crear socket nuevo si no existe
    _socket ??= io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setAuth({'token': SessionCredentials.accessToken})
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
      isReconnecting.value = false;
      updatePresence();
      if (_hasConnectedOnce) {
        _bumpReconnect();
      } else {
        UnreadMessagesNotifier.instance.refresh();
        UnreadNotificationsNotifier.instance.refresh();
      }
      _hasConnectedOnce = true;
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

    _socket!.off('notification.new');
    _socket!.on('notification.new', (dynamic packet) {
      final data = packet is List ? packet.first : packet;
      final ack = packet is List && packet.length > 1 ? packet.last : null;
      final displayed = data is Map && PushNotificationService.present(Map<String, dynamic>.from(data));
      if (ack is Function) ack({'displayed': displayed});
    });
    _socket!.off('notifications.changed');
    _socket!.on('notifications.changed', (_) => UnreadNotificationsNotifier.instance.refresh());
    _socket!.off('message.new', _refreshUnread);
    _socket!.on('message.new', _refreshUnread);
    _socket!.off('notification.toast');
    _socket!.on('notification.toast', _onNotificationToast);
  }

  void _onDisconnect(dynamic reason) {
    isConnectedNotifier.value = false;
    // 'io client disconnect' = lo cerramos nosotros (logout/cambio de cuenta).
    if (reason?.toString() != 'io client disconnect') {
      isReconnecting.value = true;
    }
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

  void _refreshUnread(dynamic _) => UnreadMessagesNotifier.instance.refresh();

  void updatePresence() {
    _socket?.emit('presence.update', {'visible': WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      'token': SessionCredentials.pushToken});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    updatePresence();
    if (state == AppLifecycleState.resumed) {
      _bumpReconnect();
    }
  }

  static const Duration _reconnectBumpMinGap = Duration(seconds: 10);
  DateTime? _lastReconnectBump;

  /// Avisa a las pantallas que deben re-consultar al backend. Con una red
  /// inestable el socket cae y vuelve cada pocos segundos; sin este límite cada
  /// reconexión disparaba a la vez mensajes, notificaciones y solicitudes
  /// (ráfagas de peticiones duplicadas). Como máximo una vez cada 10 s.
  void _bumpReconnect() {
    final now = DateTime.now();
    final last = _lastReconnectBump;
    if (last != null && now.difference(last) < _reconnectBumpMinGap) return;
    _lastReconnectBump = now;
    reconnectCount.value++;
    UnreadMessagesNotifier.instance.refresh();
    UnreadNotificationsNotifier.instance.refresh();
  }

  void leaveThread(String id) {
    _joinedThreadIds.remove(id);
    _socket?.emit('leave.thread', {'threadId': id});
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
    isReconnecting.value = false;
  }

  void dispose() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    _socket?.dispose();
    _socket = null;
    _connectedUserId = null;
    _joinedThreadIds.clear();
    isConnectedNotifier.value = false;
    isReconnecting.value = false;
    _hasConnectedOnce = false;
  }
}
