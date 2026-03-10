import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_service.dart';

class MobileBackendService {
  static Map<String, dynamic> _cleanQuery(Map<String, dynamic> values) {
    final copy = Map<String, dynamic>.from(values);
    copy.removeWhere((key, value) => value == null);
    return copy;
  }

  MobileBackendService._();

  static final http.Client _client = http.Client();
  static final ApiService _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    client: _client,
  );

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return _api.post(
      '/auth/login',
      body: {'identifier': identifier, 'password': password},
    );
  }

  static Future<Map<String, dynamic>> register({
    required String type,
    required String email,
    String? phone,
    required String firstName,
    String? lastName,
    required String password,
  }) {
    return _api.post(
      '/auth/register',
      body: {
        'type': type,
        'email': email,
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> explore({required String userId}) {
    return _api.get('/mobile/explore', queryParameters: {'userId': userId});
  }

  static Future<Map<String, dynamic>> createRequest({
    required String clientUserId,
    required String title,
    required String description,
    required String category,
    required double budget,
    required String priceType,
    required String address,
    required double latitude,
    required double longitude,
    String? scheduledAt,
  }) {
    return _api.post(
      '/mobile/requests',
      body: {
        'clientUserId': clientUserId,
        'title': title,
        'description': description,
        'category': category,
        'budget': budget,
        'priceType': priceType,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'scheduledAt': scheduledAt,
      },
    );
  }

  static Future<Map<String, dynamic>> requestStatus({
    String? requestId,
    String? clientUserId,
  }) {
    return _api.get(
      '/mobile/request-status',
      queryParameters: _cleanQuery({
        'requestId': requestId,
        'clientUserId': clientUserId,
      }),
    );
  }

  static Future<Map<String, dynamic>> offers({
    String? requestId,
    String? clientUserId,
  }) {
    return _api.get(
      '/mobile/offers',
      queryParameters: _cleanQuery({
        'requestId': requestId,
        'clientUserId': clientUserId,
      }),
    );
  }

  static Future<Map<String, dynamic>> workerProfile(String workerId) {
    return _api.get('/mobile/workers/$workerId/profile');
  }

  static Future<Map<String, dynamic>> messages({required String userId}) {
    return _api.get('/mobile/messages', queryParameters: {'userId': userId});
  }

  static Future<Map<String, dynamic>> threadMessages({
    required String threadId,
  }) {
    return _api.get('/mobile/messages/$threadId');
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    required String senderUserId,
    required String content,
  }) {
    return _api.post(
      '/mobile/messages/$threadId',
      body: {'senderUserId': senderUserId, 'content': content},
    );
  }

  static Future<Map<String, dynamic>> incomingRequest({
    required String workerUserId,
  }) {
    return _api.get(
      '/mobile/incoming-request',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  static Future<Map<String, dynamic>> counterOffer({
    required String requestId,
    required String workerUserId,
    required double amount,
    String? message,
  }) {
    return _api.post(
      '/mobile/offers/counter',
      body: {
        'requestId': requestId,
        'workerUserId': workerUserId,
        'amount': amount,
        'message': message,
      },
    );
  }

  static Future<Map<String, dynamic>> acceptOffer({
    required String offerId,
    required String clientUserId,
  }) {
    return _api.post(
      '/mobile/offers/accept',
      body: {'offerId': offerId, 'clientUserId': clientUserId},
    );
  }

  static Future<Map<String, dynamic>> tracking({required String requestId}) {
    return _api.get(
      '/mobile/tracking',
      queryParameters: {'requestId': requestId},
    );
  }

  static Future<Map<String, dynamic>> workerRadar({
    required String workerUserId,
  }) {
    return _api.get(
      '/mobile/worker/radar',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  static Future<Map<String, dynamic>> setAvailability({
    required String workerUserId,
    required bool available,
  }) {
    return _api.post(
      '/mobile/worker/availability',
      body: {'workerUserId': workerUserId, 'available': available},
    );
  }

  static Future<Map<String, dynamic>> workerSkills({
    required String workerUserId,
  }) {
    return _api.get(
      '/mobile/worker/skills',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  static Future<Map<String, dynamic>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  }) {
    return _api.post(
      '/mobile/worker/skills',
      body: {'workerUserId': workerUserId, 'skills': skills},
    );
  }

  static Future<Map<String, dynamic>> createReview({
    required String requestId,
    required String workerUserId,
    required String clientUserId,
    required int stars,
    String? comment,
  }) {
    return _api.post(
      '/mobile/reviews',
      body: {
        'requestId': requestId,
        'workerUserId': workerUserId,
        'clientUserId': clientUserId,
        'stars': stars,
        'comment': comment,
      },
    );
  }
}
