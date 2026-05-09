import '../../domain/entities/worker_radar_summary.dart';

class WorkerRadarSummaryModel extends WorkerRadarSummary {
  const WorkerRadarSummaryModel({
    required super.jobsToday,
    required super.earningsToday,
    required super.nearbyRequests,
    required super.available,
    required super.workRadiusKm,
    super.latitude,
    super.longitude,
  });

  factory WorkerRadarSummaryModel.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final location = (json['location'] as Map<String, dynamic>?) ?? const {};

    return WorkerRadarSummaryModel(
      jobsToday: (summary['jobsToday'] as num?)?.toInt() ?? 0,
      earningsToday: (summary['earningsToday'] as num?)?.toDouble() ?? 0,
      nearbyRequests: (summary['nearbyRequests'] as num?)?.toInt() ?? 0,
      available: json['available'] as bool? ?? true,
      workRadiusKm: (location['workRadiusKm'] as num?)?.toDouble() ?? 5,
      latitude: (location['latitude'] as num?)?.toDouble(),
      longitude: (location['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'available': available,
      'summary': {
        'jobsToday': jobsToday,
        'earningsToday': earningsToday,
        'nearbyRequests': nearbyRequests,
      },
      'location': {
        'workRadiusKm': workRadiusKm,
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }
}
