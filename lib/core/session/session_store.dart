class SessionUser {
  const SessionUser({
    required this.id,
    required this.type,
    required this.firstName,
    this.lastName,
    required this.email,
    this.phone,
    this.profilePhotoUrl,
  });

  final String id;
  final String type;
  final String firstName;
  final String? lastName;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;

  String get fullName {
    final ln = (lastName ?? '').trim();
    return ln.isEmpty ? firstName : '$firstName $ln';
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] as String,
      type: json['type'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
    );
  }
}

class SessionStore {
  const SessionStore._();

  static SessionUser? currentUser;
  static String? activeRequestId;
  static String? activeThreadId;

  static bool get isLoggedIn => currentUser != null;

  static void clear() {
    currentUser = null;
    activeRequestId = null;
    activeThreadId = null;
  }
}
