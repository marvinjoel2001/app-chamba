import 'package:flutter/foundation.dart';

class SessionCredentials {
  SessionCredentials._();
  static String? accessToken;
  static String? pushToken;
  static String? visibleThreadId;
  static String? visibleRequestId;
  static String? visibleDisputeId;
  static final ValueNotifier<int> sessionExpirations = ValueNotifier<int>(0);

  /// Ignora respuestas tardías de otra cuenta y notifica una vez por sesión.
  static void expireIfCurrent(String? requestToken) {
    if (requestToken == null || requestToken != accessToken) return;
    accessToken = null;
    sessionExpirations.value++;
  }
  static Map<String, String> get headers => {
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
}
