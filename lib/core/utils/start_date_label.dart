/// Formatea la fecha de inicio de una solicitud ('YYYY-MM-DD' o
/// 'YYYY-MM-DDTHH:mm:ss') como texto legible relativo: "Empieza hoy",
/// "Empieza mañana a las 08:00", "Empieza el 12 jul", etc.
String? startDateLabel(dynamic rawStartDate) {
  final raw = rawStartDate?.toString().trim() ?? '';
  if (raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  final hasTime = raw.contains('T');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(parsed.year, parsed.month, parsed.day);
  final dayDiff = startDay.difference(today).inDays;

  String dayPart;
  if (dayDiff <= 0) {
    dayPart = 'hoy';
  } else if (dayDiff == 1) {
    dayPart = 'mañana';
  } else {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    dayPart = 'el ${parsed.day} ${months[parsed.month - 1]}';
  }

  if (!hasTime) return 'Empieza $dayPart';

  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  return 'Empieza $dayPart a las $hh:$mm';
}
