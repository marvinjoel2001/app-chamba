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

  static Future<Map<String, dynamic>> checkIdentifier({
    required String identifier,
  }) {
    return _api.post(
      '/auth/check-identifier',
      body: {'identifier': identifier},
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

  static Future<Map<String, dynamic>> explore({
    required String userId,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return _api.get(
      '/mobile/explore',
      queryParameters: _cleanQuery({
        'userId': userId,
        'lat': latitude,
        'lng': longitude,
        'radiusKm': radiusKm,
      }),
    );
  }

  static Future<Map<String, dynamic>> createRequest({
    required String clientUserId,
    required String title,
    required String description,
    String? category,
    List<Map<String, dynamic>>? aiCategories,
    required double budget,
    required String priceType,
    required String address,
    required double latitude,
    required double longitude,
    String? scheduledAt,
    List<String>? photosBase64,
    List<Map<String, String>>? photos,
  }) {
    final body = <String, dynamic>{
      'clientUserId': clientUserId,
      'title': title,
      'description': description,
      'budget': budget,
      'priceType': priceType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'scheduledAt': scheduledAt,
      'photosBase64': photosBase64,
      'photos': photos,
    };
    if (category != null && category.trim().isNotEmpty) {
      body['category'] = category;
    }
    if (aiCategories != null && aiCategories.isNotEmpty) {
      body['aiCategories'] = aiCategories;
    }

    return _api.post('/mobile/requests', body: body);
  }

  static Future<Map<String, dynamic>> previewRequestCategories({
    String? title,
    required String description,
    String? category,
  }) {
    return _api.post(
      '/mobile/request-categories/preview',
      body: {
        'title': title,
        'description': description,
        'category': category,
      },
    );
  }

  static Future<Map<String, dynamic>> categories() {
    return _api.get('/mobile/categories');
  }

  static Future<Map<String, dynamic>> createCategory({
    required String name,
    String? id,
    String? description,
    String? icon,
    String? parentId,
    bool active = true,
  }) {
    return _api.post(
      '/mobile/categories',
      body: {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'parentId': parentId,
        'active': active,
      },
    );
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto({
    required String userId,
    String? imageBase64,
    String? imageUrl,
    String? imagePublicId,
  }) {
    return _api.post(
      '/mobile/profile/photo',
      body: {
        'userId': userId,
        'imageBase64': imageBase64,
        'imageUrl': imageUrl,
        'imagePublicId': imagePublicId,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteProfilePhoto({
    required String userId,
  }) {
    return _api.post('/mobile/profile/photo/delete', body: {'userId': userId});
  }

  static Future<Map<String, dynamic>> deleteRequestPhoto({
    required String requestPhotoId,
    required String clientUserId,
  }) {
    return _api.post(
      '/mobile/requests/photos/delete',
      body: {'requestPhotoId': requestPhotoId, 'clientUserId': clientUserId},
    );
  }

  static Future<Map<String, dynamic>> registerPushToken({
    required String userId,
    required String token,
    required String platform,
  }) {
    return _api.post(
      '/mobile/push/token',
      body: {'userId': userId, 'token': token, 'platform': platform},
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

  static Future<Map<String, dynamic>> workerHistory({
    required String workerUserId,
  }) {
    return _api.get(
      '/mobile/worker/history',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  static Future<Map<String, dynamic>> updateWorkerLocation({
    required String workerUserId,
    required double latitude,
    required double longitude,
  }) {
    return _api.post(
      '/mobile/worker/location',
      body: {
        'workerUserId': workerUserId,
        'latitude': latitude,
        'longitude': longitude,
      },
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
