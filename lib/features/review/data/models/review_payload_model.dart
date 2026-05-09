import '../../domain/entities/review_payload_entity.dart';

class ReviewPayloadModel extends ReviewPayloadEntity {
  const ReviewPayloadModel({required super.payload});

  factory ReviewPayloadModel.fromJson(Map<String, dynamic> json) {
    return ReviewPayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
