import '../../domain/entities/messages_payload_entity.dart';

class MessagesPayloadModel extends MessagesPayloadEntity {
  const MessagesPayloadModel({required super.payload});

  factory MessagesPayloadModel.fromJson(Map<String, dynamic> json) {
    return MessagesPayloadModel(payload: json);
  }

  Map<String, dynamic> toJson() => payload;
}
