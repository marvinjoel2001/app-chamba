import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  SessionUser copyWith({
    String? id,
    String? type,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? profilePhotoUrl,
    bool clearProfilePhotoUrl = false,
  }) {
    return SessionUser(
      id: id ?? this.id,
      type: type ?? this.type,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhotoUrl: clearProfilePhotoUrl
          ? null
          : profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'profilePhotoUrl': profilePhotoUrl,
    };
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

  static const _keySessionUser = 'session_user';

  static SessionUser? currentUser;
  static String? activeRequestId;
  static String? activeThreadId;

  static bool get isLoggedIn => currentUser != null;

  static Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySessionUser);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        currentUser = SessionUser.fromJson(decoded);
      }
    } catch (_) {
      await prefs.remove(_keySessionUser);
    }
  }

  static Future<void> setCurrentUser(SessionUser user) async {
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionUser, jsonEncode(user.toJson()));
  }

  static Future<void> persistCurrentUser() async {
    final user = currentUser;
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_keySessionUser);
      return;
    }
    await prefs.setString(_keySessionUser, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    currentUser = null;
    activeRequestId = null;
    activeThreadId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionUser);
  }
}
