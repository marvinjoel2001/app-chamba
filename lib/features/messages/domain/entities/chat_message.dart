enum ChatMessageType {
  text,
  system,
}

enum SystemMessageEvent {
  dealConfirmed,
  workerOnTheWay,
  workStarted,
  workCompleted,
  paymentConfirmed,
  generic,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    this.content,
    this.type = ChatMessageType.text,
    this.systemEvent,
    this.systemData,
    this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderUserId;
  final String? content;
  final ChatMessageType type;
  final SystemMessageEvent? systemEvent;
  final Map<String, dynamic>? systemData;
  final DateTime? createdAt;

  bool get isSystem => type == ChatMessageType.system;
  bool get isText => type == ChatMessageType.text;

  String get displayContent {
    if (isText && content != null) {
      return content!;
    }
    return _formatSystemMessage();
  }

  String _formatSystemMessage() {
    final price = systemData?['price'];
    final workerName = systemData?['workerName'] ?? systemData?['workerFirstName'];
    
    switch (systemEvent) {
      case SystemMessageEvent.dealConfirmed:
        if (price != null) {
          return 'Trato confirmado — Bs $price';
        }
        return 'Trato confirmado';
      case SystemMessageEvent.workerOnTheWay:
        if (workerName != null) {
          return '$workerName está en camino';
        }
        return 'El trabajador está en camino';
      case SystemMessageEvent.workStarted:
        return 'Trabajo iniciado';
      case SystemMessageEvent.workCompleted:
        return 'Trabajo completado';
      case SystemMessageEvent.paymentConfirmed:
        return 'Pago confirmado';
      case SystemMessageEvent.generic:
      case null:
        return content ?? 'Actualización del sistema';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.id == id &&
        other.threadId == threadId &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, threadId, type);
}
