/// Modalidades de cobro que el trabajador ofrece como punto de partida.
/// Los valores válidos coinciden con los del backend: 'fixed', 'hourly', 'daily'.
class WorkerModalities {
  const WorkerModalities({
    required this.modalities,
    this.hourlyRate,
    this.dailyRate,
  });

  final Set<String> modalities;
  final double? hourlyRate;
  final double? dailyRate;

  bool get hasFixed => modalities.contains('fixed');
  bool get hasHourly => modalities.contains('hourly');
  bool get hasDaily => modalities.contains('daily');

  const WorkerModalities.empty()
      : modalities = const <String>{},
        hourlyRate = null,
        dailyRate = null;
}
