class SessionCredentials {
  SessionCredentials._();
  static String? accessToken;
  static String? pushToken;
  static String? visibleThreadId;
  static String? visibleRequestId;
  static String? visibleDisputeId;
  static Map<String, String> get headers => {
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
}
