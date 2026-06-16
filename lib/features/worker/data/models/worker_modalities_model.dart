import '../../domain/entities/worker_modalities.dart';

class WorkerModalitiesModel extends WorkerModalities {
  const WorkerModalitiesModel({
    required super.modalities,
    super.hourlyRate,
    super.dailyRate,
  });

  factory WorkerModalitiesModel.fromJson(Map<String, dynamic> json) {
    final rawModalities = json['modalities'] as List<dynamic>? ?? const [];
    final modalities = rawModalities
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();

    double? parseRate(Object? value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    return WorkerModalitiesModel(
      modalities: modalities,
      hourlyRate: parseRate(json['hourlyRate']),
      dailyRate: parseRate(json['dailyRate']),
    );
  }
}
