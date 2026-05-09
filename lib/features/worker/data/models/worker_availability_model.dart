import '../../domain/entities/worker_availability.dart';

class WorkerAvailabilityModel extends WorkerAvailability {
  const WorkerAvailabilityModel({required super.available});

  factory WorkerAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return WorkerAvailabilityModel(
      available: json['available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {'available': available};
}
