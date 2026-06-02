import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_store.dart';
import '../models/app_notification.dart';

class NotificationsService {
  static Future<({List<AppNotification> items, bool hasMore})>
      getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return (items: <AppNotification>[], hasMore: false);

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiClient.baseUrl}/mobile/notifications?userId=$userId&page=$page&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>)
            .map((json) =>
                AppNotification.fromJson(json as Map<String, dynamic>))
            .toList();
        final hasMore = data['hasMore'] as bool? ?? false;
        return (items: items, hasMore: hasMore);
      }
    } catch (e) {
      // Ignorar error de red
    }
    return (items: <AppNotification>[], hasMore: false);
  }

  static Future<void> markAsRead() async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return;

    try {
      await http.patch(
        Uri.parse('${ApiClient.baseUrl}/mobile/notifications/read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
    } catch (e) {
      // Ignorar error de red
    }
  }
}
