import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_store.dart';
import '../domain/models/app_notification.dart';

class NotificationsService {
  static Future<({List<AppNotification> items, bool hasMore})>
      getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return (items: <AppNotification>[], hasMore: false);

    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/mobile/notifications?userId=$userId&page=$page&limit=$limit',
            ),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>)
            .map((json) =>
                AppNotification.fromJson(json as Map<String, dynamic>))
            .toList();
        final hasMore = data['hasMore'] as bool? ?? false;
        return (items: items, hasMore: hasMore);
      } else {
        throw Exception('Error al obtener notificaciones (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Fallo al obtener notificaciones: $e');
    }
  }

  static Future<void> markAsRead() async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await http
          .patch(
            Uri.parse('${AppConfig.apiBaseUrl}/mobile/notifications/read'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 12));
          
      if (response.statusCode != 200) {
        throw Exception('Error al marcar notificaciones como leídas (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Fallo al marcar notificaciones como leídas: $e');
    }
  }

  static Future<int> getUnreadCount() async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/mobile/notifications/unread-count?userId=$userId',
            ),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['count'] as num?)?.toInt() ?? 0;
      } else {
        throw Exception('Error al obtener conteo de notificaciones (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Fallo al obtener conteo de notificaciones: $e');
    }
  }
}
