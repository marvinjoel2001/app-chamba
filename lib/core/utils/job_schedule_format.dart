/// Fechas de trabajos programados en palabras simples: "Hoy 14:00",
/// "Mañana 08:00", "sáb 9 · 08:00".
///
/// `startDate` llega del backend como 'YYYY-MM-DD' o 'YYYY-MM-DDTHH:mm:00'
/// (hora de Bolivia, sin zona).
library;

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Día (sin hora) en que empieza el trabajo, o null si no tiene fecha.
DateTime? jobStartDay(String? startDate) {
  final raw = startDate?.trim() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Hora "HH:mm" si el cliente la eligió.
String? jobStartTime(String? startDate) {
  final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(startDate ?? '');
  return match == null ? null : '${match.group(1)}:${match.group(2)}';
}

/// "Hoy", "Mañana" o "sáb 9" (con el mes si no es este mes).
String jobDayLabel(DateTime day, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final diff = _dateOnly(day).difference(today).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  final base = '${_weekdays[day.weekday - 1]} ${day.day}';
  return day.month == today.month && day.year == today.year
      ? base
      : '$base ${_months[day.month - 1]}';
}

/// Texto corto para tarjetas: "Mañana 08:00", "sáb 9 · 3 días".
String formatJobStart(String? startDate, {int? days, DateTime? now}) {
  final day = jobStartDay(startDate);
  if (day == null) return 'Sin fecha';
  final parts = <String>[jobDayLabel(day, now: now)];
  final time = jobStartTime(startDate);
  if (time != null) parts.add(time);
  var text = parts.join(' ');
  if (days != null && days > 1) text = '$text · $days días';
  return text;
}

/// True si el trabajo empieza otro día, después de hoy. Hasta ese día
/// nadie está "en camino" ni puede marcar la llegada.
bool isJobForLaterDay(String? startDate, {DateTime? now}) {
  final day = jobStartDay(startDate);
  if (day == null) return false;
  return day.isAfter(_dateOnly(now ?? DateTime.now()));
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
