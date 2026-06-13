import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '../../features/notifications/data/notifications_service.dart';
import 'session_store.dart';

class UnreadNotificationsNotifier extends ValueNotifier<int> {
  UnreadNotificationsNotifier._() : super(0) {
    _startPolling();
  }

  static final UnreadNotificationsNotifier instance =
      UnreadNotificationsNotifier._();

  Timer? _timer;

  void _startPolling() {
    _fetchCount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchCount();
    });
  }

  Future<void> _fetchCount() async {
    if (!SessionStore.isLoggedIn) {
      if (value != 0) {
        value = 0;
        await _updateAppBadge(0);
      }
      return;
    }

    final count = await NotificationsService.getUnreadCount();
    if (count != value) {
      value = count;
      await _updateAppBadge(count);
    }
  }

  Future<void> markAllAsRead() async {
    value = 0;
    await _updateAppBadge(0);
  }

  Future<void> _updateAppBadge(int count) async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        if (count > 0) {
          await FlutterAppBadger.updateBadgeCount(count);
        } else {
          await FlutterAppBadger.removeBadge();
        }
      }
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
