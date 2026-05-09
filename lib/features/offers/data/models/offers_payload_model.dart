import '../../domain/entities/offers_payload_entity.dart';

class OffersPayloadModel extends OffersPayloadEntity {
  const OffersPayloadModel({required super.payload});

  factory OffersPayloadModel.fromJson(Map<String, dynamic> json) {
    return OffersPayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
