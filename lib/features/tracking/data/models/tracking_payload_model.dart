import '../../domain/entities/tracking_payload_entity.dart';

class TrackingPayloadModel extends TrackingPayloadEntity {
  const TrackingPayloadModel({required super.payload});

  factory TrackingPayloadModel.fromJson(Map<String, dynamic> json) {
    return TrackingPayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
