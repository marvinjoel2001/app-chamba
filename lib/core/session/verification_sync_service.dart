import 'package:flutter/foundation.dart';

import '../services/mobile_backend_service.dart';
import 'session_credentials.dart';
import 'session_store.dart';

/// Recovers verification changes missed while the worker was offline.
class VerificationSyncService {
  VerificationSyncService({Future<Map<String, dynamic>> Function()? fetch})
      : _fetch = fetch ?? MobileBackendService.instance.myVerification;

  static final instance = VerificationSyncService();
  final Future<Map<String, dynamic>> Function() _fetch;
  Future<void>? _pending;
  String? _pendingToken;

  Future<void> refresh() {
    final user = SessionStore.currentUser;
    final token = SessionCredentials.accessToken;
    if (user == null || user.type != 'worker' || token == null) {
      return Future.value();
    }
    if (_pending != null && _pendingToken == token) return _pending!;
    final revision = SessionStore.userChanges.value;
    _pendingToken = token;
    late final Future<void> request;
    request = _refresh(user.id, token, revision).whenComplete(() {
      if (identical(_pending, request)) {
        _pending = null;
        _pendingToken = null;
      }
    });
    return _pending = request;
  }

  Future<void> _refresh(String userId, String token, int revision) async {
    final response = await _fetch();
    final current = SessionStore.currentUser;
    // A response from an old session or from before a live update must not
    // overwrite the new state (or bring a signed-out account back).
    if (current?.id != userId ||
        SessionCredentials.accessToken != token ||
        SessionStore.userChanges.value != revision) {
      return;
    }
    final raw = response['user'];
    if (raw is! Map ||
        raw['id'] != userId ||
        !['verified', 'pending', 'not_verified']
            .contains(raw['verificationStatus'])) {
      throw const FormatException('Invalid verification response');
    }
    final data = current!.toJson();
    for (final field in const [
      'verificationStatus',
      'idPhotoUrl',
      'facePhotoUrl',
      'idPhotoVerified',
      'facePhotoVerified',
    ]) {
      if (raw.containsKey(field)) data[field] = raw[field];
    }
    if (mapEquals(data, current.toJson())) return;
    await SessionStore.setCurrentUser(SessionUser.fromJson(data));
  }

  /// Background synchronization must never interrupt navigation or sign-in.
  Future<void> refreshQuietly() async {
    try {
      await refresh();
    } catch (error) {
      debugPrint('Could not refresh verification: $error');
    }
  }
}
