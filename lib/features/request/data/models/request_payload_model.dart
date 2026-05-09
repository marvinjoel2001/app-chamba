import '../../domain/entities/request_payload_entity.dart';

class RequestPayloadModel extends RequestPayloadEntity {
  const RequestPayloadModel({required super.payload});

  factory RequestPayloadModel.fromJson(Map<String, dynamic> json) {
    return RequestPayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
