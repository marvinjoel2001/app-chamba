enum ChatThreadStatus {
  active,
  completed,
  cancelled,
}

enum ChatThreadType {
  active,
  archived,
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.jobDescription,
    required this.jobStatus,
    required this.agreedPrice,
    required this.counterpartName,
    this.counterpartFirstName,
    this.counterpartLastName,
    this.counterpartProfilePhotoUrl,
    this.category,
    this.workerId,
    this.clientId,
    this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.hasUnreadMessages = false,
    this.type = ChatThreadType.active,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String jobDescription;
  final ChatThreadStatus jobStatus;
  final double agreedPrice;
  final String counterpartName;
  final String? counterpartFirstName;
  final String? counterpartLastName;
  final String? counterpartProfilePhotoUrl;
  final String? category;
  final String? workerId;
  final String? clientId;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final bool hasUnreadMessages;
  final ChatThreadType type;

  bool get isActive => jobStatus == ChatThreadStatus.active;
  bool get isCompleted => jobStatus == ChatThreadStatus.completed;
  bool get isCancelled => jobStatus == ChatThreadStatus.cancelled;
  bool get isArchived => type == ChatThreadType.archived;

  String get statusLabel {
    switch (jobStatus) {
      case ChatThreadStatus.active:
        return 'Activo';
      case ChatThreadStatus.completed:
        return 'Completado';
      case ChatThreadStatus.cancelled:
        return 'Cancelado';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatThread &&
        other.id == id &&
        other.jobId == jobId &&
        other.jobStatus == jobStatus &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, jobId, jobStatus, type);
}
