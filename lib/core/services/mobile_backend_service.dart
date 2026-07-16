import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../network/api_service.dart';

class MobileBackendService {
  static const MobileBackendService instance = MobileBackendService._();

  static Map<String, dynamic> _cleanQuery(Map<String, dynamic> values) {
    final copy = Map<String, dynamic>.from(values);
    copy.removeWhere((key, value) => value == null);
    return copy;
  }

  const MobileBackendService._();

  static final http.Client _client = http.Client();
  static final ApiService _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    client: _client,
  );

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return _api.post(
      '/auth/login',
      body: {'identifier': identifier, 'password': password},
    );
  }

  Future<Map<String, dynamic>> checkIdentifier({required String identifier}) {
    return _api.post(
      '/auth/check-identifier',
      body: {'identifier': identifier},
    );
  }

  Future<Map<String, dynamic>> register({
    required String type,
    required String email,
    String? phone,
    String? countryCode,
    String? ciNumber,
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
        'countryCode': countryCode,
        'ciNumber': ciNumber,
        'firstName': firstName,
        'lastName': lastName,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) {
    return _api.post('/auth/google', body: {'idToken': idToken});
  }

  Future<Map<String, dynamic>> registerWithGoogle({
    required String email,
    required String firstName,
    String? lastName,
    required String googleId,
    required String type,
  }) {
    return _api.post(
      '/auth/google/register',
      body: {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'googleId': googleId,
        'type': type,
      },
    );
  }

  Future<Map<String, dynamic>> explore({
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

  Future<Map<String, dynamic>> createRequest({
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
    String? paymentMethod,
    String? modality,
    int? estimatedHours,
    double? hourlyRate,
    int? days,
    double? dailyRate,
    String? startDate,
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
      'paymentMethod': paymentMethod,
      'modality': modality,
      'estimatedHours': estimatedHours,
      'hourlyRate': hourlyRate,
      'days': days,
      'dailyRate': dailyRate,
      'startDate': startDate,
    };
    if (category != null && category.trim().isNotEmpty) {
      body['category'] = category;
    }
    if (aiCategories != null && aiCategories.isNotEmpty) {
      body['aiCategories'] = aiCategories;
    }

    return _api.post('/mobile/requests', body: body);
  }

  Future<Map<String, dynamic>> previewRequestCategories({
    String? title,
    required String description,
    String? category,
  }) {
    return _api.post(
      '/mobile/request-categories/preview',
      body: {'title': title, 'description': description, 'category': category},
    );
  }

  Future<Map<String, dynamic>> categories() {
    return _api.get('/mobile/categories');
  }

  Future<Map<String, dynamic>> createCategory({
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

  Future<Map<String, dynamic>> uploadProfilePhoto({
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

  Future<Map<String, dynamic>> deleteProfilePhoto({required String userId}) {
    return _api.post('/mobile/profile/photo/delete', body: {'userId': userId});
  }

  Future<Map<String, dynamic>> submitWorkerVerification({
    required String workerUserId,
    required String idPhotoBase64,
    required String facePhotoBase64,
  }) {
    return _api.post(
      '/mobile/worker/verification',
      body: {
        'workerUserId': workerUserId,
        'idPhotoBase64': idPhotoBase64,
        'facePhotoBase64': facePhotoBase64,
      },
    );
  }

  Future<Map<String, dynamic>> deleteRequestPhoto({
    required String requestPhotoId,
    required String clientUserId,
  }) {
    return _api.post(
      '/mobile/requests/photos/delete',
      body: {'requestPhotoId': requestPhotoId, 'clientUserId': clientUserId},
    );
  }

  Future<Map<String, dynamic>> registerPushToken({
    required String userId,
    required String token,
    required String platform,
  }) {
    return _api.post(
      '/mobile/push/token',
      body: {'userId': userId, 'token': token, 'platform': platform},
    );
  }

  Future<Map<String, dynamic>> requestStatus({
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

  Future<Map<String, dynamic>> offers({
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

  Future<Map<String, dynamic>> workerProfile(String workerId) {
    return _api.get('/mobile/workers/$workerId/profile');
  }

  Future<Map<String, dynamic>> messages({required String userId}) {
    return _api.get('/mobile/messages', queryParameters: {'userId': userId});
  }

  Future<Map<String, dynamic>> threadMessages({required String threadId}) {
    return _api.get('/mobile/messages/$threadId');
  }

  Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    required String senderUserId,
    required String content,
  }) {
    return _api.post(
      '/mobile/messages/$threadId',
      body: {'senderUserId': senderUserId, 'content': content},
    );
  }

  Future<Map<String, dynamic>> archiveThread({
    required String threadId,
    required String userId,
  }) {
    return _api.post(
      '/mobile/messages/$threadId/archive',
      body: {'userId': userId},
    );
  }

  Future<Map<String, dynamic>> deleteThread({
    required String threadId,
    required String userId,
  }) {
    return _api.post(
      '/mobile/messages/$threadId/delete',
      body: {'userId': userId},
    );
  }

  Future<Map<String, dynamic>> markThreadRead({
    required String threadId,
    required String userId,
  }) {
    return _api.post(
      '/mobile/messages/$threadId/read',
      body: {'userId': userId},
    );
  }

  Future<Map<String, dynamic>> incomingRequest({required String workerUserId}) {
    return _api.get(
      '/mobile/incoming-request',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> blockClient({
    required String workerUserId,
    required String clientUserId,
  }) {
    return _api.post(
      '/mobile/users/$workerUserId/block',
      body: {'blockedUserId': clientUserId},
    );
  }

  Future<Map<String, dynamic>> reportRequest({
    required String requestId,
    required String reporterUserId,
    required String reason,
  }) {
    return _api.post(
      '/mobile/requests/$requestId/report',
      body: {'reporterUserId': reporterUserId, 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> dismissRequest({
    required String requestId,
    required String workerUserId,
  }) {
    return _api.post(
      '/mobile/requests/$requestId/dismiss',
      body: {'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> counterOffer({
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

  Future<Map<String, dynamic>> acceptOffer({
    required String offerId,
    required String clientUserId,
  }) {
    return _api.post(
      '/mobile/offers/accept',
      body: {'offerId': offerId, 'clientUserId': clientUserId},
    );
  }

  Future<Map<String, dynamic>> tracking({required String requestId}) {
    return _api.get(
      '/mobile/tracking',
      queryParameters: {'requestId': requestId},
    );
  }

  Future<Map<String, dynamic>> workerRadar({required String workerUserId}) {
    return _api.get(
      '/mobile/worker/radar',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> setAvailability({
    required String workerUserId,
    required bool available,
  }) {
    return _api.post(
      '/mobile/worker/availability',
      body: {'workerUserId': workerUserId, 'available': available},
    );
  }

  Future<Map<String, dynamic>> workerSkills({required String workerUserId}) {
    return _api.get(
      '/mobile/worker/skills',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> updateWorkerSkills({
    required String workerUserId,
    required List<String> skills,
  }) {
    return _api.post(
      '/mobile/worker/skills',
      body: {'workerUserId': workerUserId, 'skills': skills},
    );
  }

  Future<Map<String, dynamic>> workerModalities({
    required String workerUserId,
  }) {
    return _api.get(
      '/mobile/worker/modalities',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> updateWorkerModalities({
    required String workerUserId,
    required List<String> modalities,
    double? hourlyRate,
    double? dailyRate,
  }) {
    return _api.post(
      '/mobile/worker/modalities',
      body: {
        'workerUserId': workerUserId,
        'modalities': modalities,
        'hourlyRate': hourlyRate,
        'dailyRate': dailyRate,
      },
    );
  }

  Future<Map<String, dynamic>> workerHistory({required String workerUserId}) {
    return _api.get(
      '/mobile/worker/history',
      queryParameters: {'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> updateWorkerLocation({
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

  Future<Map<String, dynamic>> createReview({
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

  Future<Map<String, dynamic>> workerMarkArrived({
    required String requestId,
    required String workerUserId,
  }) {
    return _api.post(
      '/mobile/tracking/worker-arrived',
      body: {'requestId': requestId, 'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> clientConfirmArrival({
    required String requestId,
    required String clientUserId,
  }) {
    return _api.post(
      '/mobile/tracking/client-confirm',
      body: {'requestId': requestId, 'clientUserId': clientUserId},
    );
  }

  Future<Map<String, dynamic>> completeJob({
    required String requestId,
    required String workerUserId,
  }) {
    return _api.post(
      '/mobile/tracking/complete',
      body: {'requestId': requestId, 'workerUserId': workerUserId},
    );
  }

  Future<Map<String, dynamic>> cancelJob({
    required String requestId,
    required String userId,
  }) {
    return _api.post(
      '/mobile/tracking/cancel',
      body: {'requestId': requestId, 'userId': userId},
    );
  }

  // Worker descarta su oferta pendiente → vuelve al estado sin oferta
  Future<Map<String, dynamic>> discardOffer({
    required String requestId,
    required String workerUserId,
  }) {
    return _api.post(
      '/mobile/offers/discard',
      body: {'requestId': requestId, 'workerUserId': workerUserId},
    );
  }

  // Cliente hace contraoferta (sube su propio precio)
  Future<Map<String, dynamic>> clientCounterOffer({
    required String requestId,
    required String clientUserId,
    required double amount,
  }) {
    return _api.post(
      '/mobile/offers/client-counter',
      body: {
        'requestId': requestId,
        'clientUserId': clientUserId,
        'amount': amount,
      },
    );
  }

  // Worker marca oferta como "no me interesa" (declined)
  Future<Map<String, dynamic>> declineOffer({
    required String requestId,
    required String workerUserId,
  }) {
    return _api.post(
      '/mobile/offers/decline',
      body: {'requestId': requestId, 'workerUserId': workerUserId},
    );
  }

  // Worker reactiva una oferta marcada como declined
  Future<Map<String, dynamic>> reactivateOffer({
    required String requestId,
    required String workerUserId,
  }) {
    return _api.post(
      '/mobile/offers/reactivate',
      body: {'requestId': requestId, 'workerUserId': workerUserId},
    );
  }

  // --- Disputes / Soporte ---

  Future<Map<String, dynamic>> createDispute({
    String? requestId,
    required String reportedBy,
    String? reportedUser,
    required String reason,
    String? description,
  }) {
    return _api.post(
      '/mobile/disputes',
      body: {
        'requestId': requestId,
        'reportedBy': reportedBy,
        'reportedUser': reportedUser,
        'reason': reason,
        'description': description,
      },
    );
  }

  Future<Map<String, dynamic>> getDisputeMessages({
    required String disputeId,
    String? readBy,
  }) {
    final query = readBy != null ? '?readBy=$readBy' : '';
    return _api.get('/mobile/disputes/$disputeId/messages$query');
  }

  Future<Map<String, dynamic>> getUserActiveDisputes(String userId) {
    return _api.get('/mobile/disputes/user/$userId');
  }

  Future<Map<String, dynamic>> sendDisputeMessage({
    required String disputeId,
    required String senderType,
    String? senderId,
    required String content,
  }) {
    return _api.post(
      '/mobile/disputes/$disputeId/messages',
      body: {
        'senderType': senderType,
        'senderId': senderId,
        'content': content,
      },
    );
  }

  // --- History ---

  Future<Map<String, dynamic>> getWorkerHistory({required String workerUserId}) {
    return _api.get('/mobile/worker/history?workerUserId=$workerUserId');
  }

  Future<Map<String, dynamic>> getClientHistory({required String clientUserId}) {
    return _api.get('/mobile/client/history?clientUserId=$clientUserId');
  }
}
