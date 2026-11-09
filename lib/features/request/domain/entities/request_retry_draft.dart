import '../../../../core/utils/job_schedule_format.dart';

/// A new request draft preserves the advertised terms, never the former
/// worker's counteroffer or acceptance. The original request stays cancelled.
class RequestRetryDraft {
  RequestRetryDraft.fromRequest(Map<String, dynamic> request,
      {Map<String, dynamic>? destination, DateTime? now})
      : title = request['title']?.toString() ?? '',
        description = request['description']?.toString() ?? '',
        category = request['category']?.toString() ?? 'General',
        modality = request['modality']?.toString() ??
            _legacyModality(request['priceType']),
        budget = _number(request['budget']),
        estimatedHours = _integer(request['estimatedHours']),
        hourlyRate = _number(request['hourlyRate']),
        days = _integer(request['days']),
        dailyRate = _number(request['dailyRate']),
        latitude = _number(request['latitude'] ?? destination?['latitude']),
        longitude = _number(request['longitude'] ?? destination?['longitude']),
        address = request['address']?.toString(),
        // "Solo mano de obra" o "+ materiales": lo que eligió el cliente.
        materialsMode = request['materialsMode']?.toString(),
        startDate = _upcomingStart(request['startDate'], now ?? DateTime.now()) {
    if (description.trim().isEmpty ||
        !['fixed', 'hourly', 'daily'].contains(modality) ||
        (budget ?? 0) <= 0 ||
        (modality == 'hourly' &&
            ((estimatedHours ?? 0) <= 0 || (hourlyRate ?? 0) <= 0)) ||
        (modality == 'daily' && ((days ?? 0) <= 0 || (dailyRate ?? 0) <= 0))) {
      throw const FormatException('Los datos del trabajo están incompletos.');
    }
  }

  final String title, description, category, modality;
  final String? address, materialsMode;

  /// Fecha (y hora) de inicio del trabajo cancelado, solo si todavía está a
  /// más de una hora: más cerca, el backend la cancelaría al publicarla.
  final String? startDate;

  /// El backend toma las 09:00 si el cliente no eligió hora.
  static String? _upcomingStart(dynamic raw, DateTime now) {
    final text = raw?.toString().trim() ?? '';
    final day = jobStartDay(text);
    if (day == null) return null;
    final time = (jobStartTime(text) ?? '09:00').split(':');
    final start = day.add(
        Duration(hours: int.parse(time[0]), minutes: int.parse(time[1])));
    return start.isAfter(now.add(const Duration(hours: 1))) ? text : null;
  }
  final double? budget, hourlyRate, dailyRate, latitude, longitude;
  final int? estimatedHours, days;
  static int? _integer(dynamic value) {
    final number = _number(value);
    return number != null && number == number.truncateToDouble()
        ? number.toInt()
        : null;
  }

  static String _legacyModality(dynamic value) =>
      switch (value?.toString().toLowerCase()) {
        'por hora' || 'hourly' => 'hourly',
        'por día' || 'por dia' || 'daily' => 'daily',
        null || 'precio fijo' || 'por trabajo' || 'fixed' => 'fixed',
        _ => 'unknown',
      };
  static double? _number(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }
}
