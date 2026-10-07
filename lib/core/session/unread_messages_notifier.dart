import 'package:flutter/foundation.dart';
import '../services/mobile_backend_service.dart';
import 'session_store.dart';

class UnreadMessagesNotifier extends ValueNotifier<int> {
  UnreadMessagesNotifier._() : super(0);
  static final instance = UnreadMessagesNotifier._();
  bool _fetching = false;
  bool _again = false;
  Future<void> refresh() async {
    if (_fetching) {
      _again = true;
      return;
    }
    final user = SessionStore.currentUser;
    if (user == null) {
      value = 0;
      return;
    }
    _fetching = true;
    try {
      final data =
          await MobileBackendService.instance.messages(userId: user.id);
      if (SessionStore.currentUser?.id == user.id)
        value = (data['threads'] as List? ?? []).fold<int>(
            0,
            (sum, thread) =>
                sum +
                (thread['chatEnabled'] == true
                    ? ((thread['unreadCount'] as num?)?.toInt() ?? 0)
                    : 0));
    } catch (_) {
      /* Keep the last confirmed count during an outage. */
    } finally {
      _fetching = false;
      if (_again) {
        _again = false;
        refresh();
      }
    }
  }

  void increment() => refresh();
  void reset() => value = 0;
}
