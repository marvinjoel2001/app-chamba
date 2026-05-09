import '../../domain/entities/explore_payload_entity.dart';

class ExplorePayloadModel extends ExplorePayloadEntity {
  const ExplorePayloadModel({required super.payload});

  factory ExplorePayloadModel.fromJson(Map<String, dynamic> json) {
    return ExplorePayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
