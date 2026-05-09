import '../../domain/entities/worker_job.dart';

class WorkerJobModel extends WorkerJob {
  const WorkerJobModel({
    required super.id,
    required super.title,
    required super.category,
    required super.address,
    required super.amount,
    required super.status,
    required super.clientFirstName,
    required super.clientLastName,
    super.clientProfilePhotoUrl,
    super.acceptedAt,
    super.threadId,
  });

  factory WorkerJobModel.fromJson(Map<String, dynamic> json) {
    final client = (json['client'] as Map<String, dynamic>?) ?? const {};
    return WorkerJobModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Trabajo',
      category: json['category']?.toString() ?? 'General',
      address: json['address']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: _statusFromRaw(json['requestStatus']?.toString()),
      clientFirstName: client['firstName']?.toString() ?? '',
      clientLastName: client['lastName']?.toString() ?? '',
      clientProfilePhotoUrl: client['profilePhotoUrl']?.toString(),
      acceptedAt: _parseDate(json['acceptedAt']?.toString()),
      threadId: json['threadId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'address': address,
      'amount': amount,
      'requestStatus': _statusToRaw(status),
      'acceptedAt': acceptedAt?.toUtc().toIso8601String(),
      'threadId': threadId,
      'client': {
        'firstName': clientFirstName,
        'lastName': clientLastName,
        'profilePhotoUrl': clientProfilePhotoUrl,
      },
    };
  }

  static WorkerJobStatus _statusFromRaw(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'pending':
        return WorkerJobStatus.pending;
      case 'accepted':
        return WorkerJobStatus.accepted;
      case 'in_progress':
      case 'inprogress':
        return WorkerJobStatus.inProgress;
      case 'completed':
        return WorkerJobStatus.completed;
      case 'cancelled':
      case 'canceled':
        return WorkerJobStatus.cancelled;
      default:
        return WorkerJobStatus.unknown;
    }
  }

  static String _statusToRaw(WorkerJobStatus status) {
    switch (status) {
      case WorkerJobStatus.pending:
        return 'pending';
      case WorkerJobStatus.accepted:
        return 'accepted';
      case WorkerJobStatus.inProgress:
        return 'in_progress';
      case WorkerJobStatus.completed:
        return 'completed';
      case WorkerJobStatus.cancelled:
        return 'cancelled';
      case WorkerJobStatus.unknown:
        return 'unknown';
    }
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }
}
