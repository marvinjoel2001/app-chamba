import '../../domain/entities/chat_thread.dart';

class ChatThreadModel extends ChatThread {
  const ChatThreadModel({
    required super.id,
    required super.jobId,
    required super.jobTitle,
    required super.jobDescription,
    required super.jobStatus,
    required super.agreedPrice,
    required super.counterpartName,
    super.counterpartFirstName,
    super.counterpartLastName,
    super.counterpartProfilePhotoUrl,
    super.category,
    super.workerId,
    super.clientId,
    super.createdAt,
    super.lastMessageAt,
    super.lastMessage,
    super.hasUnreadMessages,
    super.type,
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>? ?? {};
    final counterpart = json['counterpart'] as Map<String, dynamic>? ?? {};

    return ChatThreadModel(
      id: json['id']?.toString() ?? '',
      jobId: request['id']?.toString() ?? json['requestId']?.toString() ?? '',
      jobTitle: request['title']?.toString()?.trim().isNotEmpty == true
          ? request['title'].toString().trim()
          : 'Solicitud de servicio',
      jobDescription: request['description']?.toString() ?? '',
      jobStatus: _parseStatus(
          request['status']?.toString() ?? json['requestStatus']?.toString()),
      agreedPrice:
          (request['budget'] as num? ?? json['agreedPrice'] as num? ?? 0)
              .toDouble(),
      counterpartName: _formatCounterpartName(counterpart),
      counterpartFirstName: counterpart['firstName']?.toString(),
      counterpartLastName: counterpart['lastName']?.toString(),
      counterpartProfilePhotoUrl: counterpart['profilePhotoUrl']?.toString(),
      category: request['category']?.toString(),
      workerId: request['workerId']?.toString() ?? json['workerId']?.toString(),
      clientId: request['clientId']?.toString() ?? json['clientId']?.toString(),
      createdAt: _parseDate(json['createdAt']?.toString()),
      lastMessageAt: _parseDate(json['lastMessageAt']?.toString()),
      lastMessage: json['lastMessage']?.toString(),
      hasUnreadMessages: json['hasUnreadMessages'] as bool? ?? false,
      type: _parseType(
          json['type']?.toString() ?? json['archived'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestId': jobId,
      'request': {
        'id': jobId,
        'title': jobTitle,
        'description': jobDescription,
        'status': _statusToString(jobStatus),
        'budget': agreedPrice,
        'category': category,
        'workerId': workerId,
        'clientId': clientId,
      },
      'counterpart': {
        'firstName': counterpartFirstName,
        'lastName': counterpartLastName,
        'profilePhotoUrl': counterpartProfilePhotoUrl,
      },
      'agreedPrice': agreedPrice,
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'lastMessageAt': lastMessageAt?.toUtc().toIso8601String(),
      'lastMessage': lastMessage,
      'hasUnreadMessages': hasUnreadMessages,
      'type': type == ChatThreadType.archived ? 'archived' : 'active',
      'archived': isArchived,
    };
  }

  static ChatThreadStatus _parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'active':
      case 'in_progress':
      case 'accepted':
        return ChatThreadStatus.active;
      case 'completed':
      case 'done':
        return ChatThreadStatus.completed;
      case 'cancelled':
      case 'canceled':
      case 'cancel':
        return ChatThreadStatus.cancelled;
      default:
        return ChatThreadStatus.active;
    }
  }

  static String _statusToString(ChatThreadStatus status) {
    switch (status) {
      case ChatThreadStatus.active:
        return 'active';
      case ChatThreadStatus.completed:
        return 'completed';
      case ChatThreadStatus.cancelled:
        return 'cancelled';
    }
  }

  static ChatThreadType _parseType(dynamic raw) {
    if (raw is bool) {
      return raw ? ChatThreadType.archived : ChatThreadType.active;
    }
    if (raw is String) {
      return raw.toLowerCase() == 'archived'
          ? ChatThreadType.archived
          : ChatThreadType.active;
    }
    return ChatThreadType.active;
  }

  static String _formatCounterpartName(Map<String, dynamic> counterpart) {
    final firstName = counterpart['firstName']?.toString() ?? '';
    final lastName = counterpart['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? 'Usuario' : fullName;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
