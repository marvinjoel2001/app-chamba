enum NotificationDisposition { defer, silent, alert }

/// Decisions shared by foreground push and socket delivery.
class NotificationPresentationPolicy {
  final Map<String, DateTime> _seen = {};
  NotificationDisposition evaluate(Map<String, dynamic> data, {
    required String? userId,
    required bool isVisible,
    String? visibleThreadId,
    String? visibleDisputeId,
    required DateTime now,
  }) {
    if (!isVisible || userId == null || (data['userId'] != null && data['userId'] != userId)) {
      return NotificationDisposition.defer;
    }
    final expiry = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    if (expiry != null && !expiry.isAfter(now)) return NotificationDisposition.silent;
    _seen.removeWhere((_, at) => now.difference(at) > const Duration(hours: 1));
    final id = data['eventId']?.toString();
    if (id != null && _seen.containsKey(id)) return NotificationDisposition.silent;
    if (id != null) _seen[id] = now;
    if (data['type'] == 'message_new' && visibleThreadId != null && data['threadId'] == visibleThreadId) {
      return NotificationDisposition.silent;
    }
    if (data['type'] == 'support_message' && visibleDisputeId != null && data['disputeId'] == visibleDisputeId) return NotificationDisposition.silent;
    return NotificationDisposition.alert;
  }
  void reset() => _seen.clear();
}
