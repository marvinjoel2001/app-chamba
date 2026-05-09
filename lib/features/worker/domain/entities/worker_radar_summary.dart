class WorkerRadarSummary {
  const WorkerRadarSummary({
    required this.jobsToday,
    required this.earningsToday,
    required this.nearbyRequests,
    required this.available,
    required this.workRadiusKm,
    this.latitude,
    this.longitude,
  });

  final int jobsToday;
  final double earningsToday;
  final int nearbyRequests;
  final bool available;
  final double workRadiusKm;
  final double? latitude;
  final double? longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerRadarSummary &&
        other.jobsToday == jobsToday &&
        other.earningsToday == earningsToday &&
        other.nearbyRequests == nearbyRequests &&
        other.available == available &&
        other.workRadiusKm == workRadiusKm &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(
    jobsToday,
    earningsToday,
    nearbyRequests,
    available,
    workRadiusKm,
    latitude,
    longitude,
  );
}
