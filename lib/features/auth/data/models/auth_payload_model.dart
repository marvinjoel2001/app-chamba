import '../../domain/entities/auth_payload_entity.dart';

class AuthPayloadModel extends AuthPayloadEntity {
  const AuthPayloadModel({required super.payload});

  factory AuthPayloadModel.fromJson(Map<String, dynamic> json) {
    return AuthPayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
