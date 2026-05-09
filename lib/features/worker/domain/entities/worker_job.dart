enum WorkerJobStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
  unknown,
}

class WorkerJob {
  const WorkerJob({
    required this.id,
    required this.title,
    required this.category,
    required this.address,
    required this.amount,
    required this.status,
    required this.clientFirstName,
    required this.clientLastName,
    this.clientProfilePhotoUrl,
    this.acceptedAt,
    this.threadId,
  });

  final String id;
  final String title;
  final String category;
  final String address;
  final double amount;
  final WorkerJobStatus status;
  final String clientFirstName;
  final String clientLastName;
  final String? clientProfilePhotoUrl;
  final DateTime? acceptedAt;
  final String? threadId;

  String get clientFullName {
    final value = '$clientFirstName $clientLastName'.trim();
    return value.isEmpty ? 'Cliente' : value;
  }

  bool get isCancelled => status == WorkerJobStatus.cancelled;
  bool get isCompleted => status == WorkerJobStatus.completed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerJob &&
        other.id == id &&
        other.title == title &&
        other.category == category &&
        other.address == address &&
        other.amount == amount &&
        other.status == status &&
        other.clientFirstName == clientFirstName &&
        other.clientLastName == clientLastName &&
        other.clientProfilePhotoUrl == clientProfilePhotoUrl &&
        other.acceptedAt == acceptedAt &&
        other.threadId == threadId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    category,
    address,
    amount,
    status,
    clientFirstName,
    clientLastName,
    clientProfilePhotoUrl,
    acceptedAt,
    threadId,
  );
}
