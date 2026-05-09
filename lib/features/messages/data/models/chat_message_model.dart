import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.threadId,
    required super.senderUserId,
    super.content,
    super.type,
    super.systemEvent,
    super.systemData,
    super.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      threadId: json['threadId']?.toString() ?? '',
      senderUserId: json['senderUserId']?.toString() ?? '',
      content: json['content']?.toString(),
      type: _parseType(json['type']?.toString()),
      systemEvent: _parseSystemEvent(json['systemEvent']?.toString()),
      systemData: json['systemData'] as Map<String, dynamic>?,
      createdAt: _parseDate(json['createdAt']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'senderUserId': senderUserId,
      'content': content,
      'type': _typeToString(type),
      'systemEvent': _systemEventToString(systemEvent),
      'systemData': systemData,
      'createdAt': createdAt?.toUtc().toIso8601String(),
    };
  }

  static ChatMessageType _parseType(String? raw) {
    return (raw ?? '').toLowerCase() == 'system' 
        ? ChatMessageType.system 
        : ChatMessageType.text;
  }

  static String _typeToString(ChatMessageType type) {
    return type == ChatMessageType.system ? 'system' : 'text';
  }

  static SystemMessageEvent? _parseSystemEvent(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'deal_confirmed':
      case 'dealconfirmed':
        return SystemMessageEvent.dealConfirmed;
      case 'worker_on_the_way':
      case 'workerontheway':
        return SystemMessageEvent.workerOnTheWay;
      case 'work_started':
      case 'workstarted':
        return SystemMessageEvent.workStarted;
      case 'work_completed':
      case 'workcompleted':
        return SystemMessageEvent.workCompleted;
      case 'payment_confirmed':
      case 'paymentconfirmed':
        return SystemMessageEvent.paymentConfirmed;
      case 'generic':
        return SystemMessageEvent.generic;
      default:
        return null;
    }
  }

  static String? _systemEventToString(SystemMessageEvent? event) {
    if (event == null) return null;
    switch (event) {
      case SystemMessageEvent.dealConfirmed:
        return 'deal_confirmed';
      case SystemMessageEvent.workerOnTheWay:
        return 'worker_on_the_way';
      case SystemMessageEvent.workStarted:
        return 'work_started';
      case SystemMessageEvent.workCompleted:
        return 'work_completed';
      case SystemMessageEvent.paymentConfirmed:
        return 'payment_confirmed';
      case SystemMessageEvent.generic:
        return 'generic';
    }
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
