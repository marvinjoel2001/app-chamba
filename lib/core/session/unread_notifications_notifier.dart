import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '../../features/notifications/data/notifications_service.dart';
import 'session_store.dart';

class UnreadNotificationsNotifier extends ValueNotifier<int> {
  UnreadNotificationsNotifier._()
      : _loadCount = NotificationsService.getUnreadCount,
        super(0) {
    _startPolling();
  }

  @visibleForTesting
  UnreadNotificationsNotifier.forTesting({
    required Future<int> Function() loadCount,
  })  : _loadCount = loadCount,
        super(0);

  final Future<int> Function() _loadCount;

  static final UnreadNotificationsNotifier instance =
      UnreadNotificationsNotifier._();

  Timer? _timer;

  void _startPolling() {
    _fetchCount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchCount();
    });
  }

  Future<void> refresh() => _fetchCount();

  Future<void>? _refreshTask;
  bool _refreshAgain = false;

  Future<void> _fetchCount() {
    final pending = _refreshTask;
    if (pending != null) {
      // A socket event may arrive after the in-flight request read the count.
      // Fetch again rather than dropping that event until the next poll.
      _refreshAgain = true;
      return pending;
    }
    return _refreshTask = _refreshUntilCurrent().whenComplete(() {
      _refreshTask = null;
    });
  }

  Future<void> _refreshUntilCurrent() async {
    do {
      _refreshAgain = false;
      await _fetchOnce();
    } while (_refreshAgain);
  }

  Future<void> _fetchOnce() async {
    if (!SessionStore.isLoggedIn) {
      if (value != 0) {
        value = 0;
        await _updateAppBadge(0);
      }
      return;
    }

    final userId = SessionStore.currentUser?.id;
    try {
      final count = await _loadCount();
      if (SessionStore.currentUser?.id == userId && count != value) {
        value = count;
        await _updateAppBadge(count);
      }
    } catch (_) {
      // Keep the last confirmed count during an outage.
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
