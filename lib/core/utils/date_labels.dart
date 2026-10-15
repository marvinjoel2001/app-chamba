/// Formatos de fecha legibles en español para avisos, mensajes y listas.
///
/// No dependen de `intl` ni de inicializar locales: así funcionan igual en el
/// arranque en frío desde un push que dentro de la app.
library;

const _monthsShort = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

const _weekdaysLong = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// `14:05`
String hourLabel(DateTime value) {
  final d = value.toLocal();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

int _daysAgo(DateTime local, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  return today.difference(day).inDays;
}

/// Día + hora siempre explícitos, para avisos y notificaciones:
/// - `Hace un momento` / `Hace 12 min` (menos de una hora)
/// - `Hoy, 14:05`
/// - `Ayer, 09:30`
/// - `lun 6 oct, 18:00` (última semana)
/// - `12 sep, 18:00` (este año)
/// - `12 sep 2025, 18:00` (otro año)
String dateTimeLabel(DateTime value, {DateTime? now, bool relative = true}) {
  final local = value.toLocal();
  final current = now ?? DateTime.now();
  final diff = current.difference(local);

  if (relative && !diff.isNegative && diff.inMinutes < 60) {
    if (diff.inMinutes < 1) return 'Hace un momento';
    return 'Hace ${diff.inMinutes} min';
  }

  final time = hourLabel(local);
  final days = _daysAgo(local, current);
  if (days == 0) return 'Hoy, $time';
  if (days == 1) return 'Ayer, $time';
  if (days == -1) return 'Mañana, $time';

  final dayMonth = '${local.day} ${_monthsShort[local.month - 1]}';
  if (days > 1 && days < 7) {
    return '${_weekdaysShort[local.weekday - 1]} $dayMonth, $time';
  }
  if (local.year == current.year) return '$dayMonth, $time';
  return '$dayMonth ${local.year}, $time';
}

/// Versión corta para la esquina de una tarjeta (sin "Hace…"):
/// `Hoy 14:05` · `Ayer 09:30` · `lun 18:00` · `6 oct` · `6 oct 2025`.
String compactDateTimeLabel(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final current = now ?? DateTime.now();
  final time = hourLabel(local);
  final days = _daysAgo(local, current);
  if (days == 0) return 'Hoy $time';
  if (days == 1) return 'Ayer $time';
  if (days > 1 && days < 7) {
    return '${_weekdaysShort[local.weekday - 1]} $time';
  }
  final dayMonth = '${local.day} ${_monthsShort[local.month - 1]}';
  if (local.year == current.year) return dayMonth;
  return '$dayMonth ${local.year}';
}

/// Hora de una burbuja de chat: solo `14:05` si es de hoy; si no, con el día
/// (`Ayer, 14:05`, `lun 6 oct, 14:05`, `12 sep, 14:05`).
String messageTimeLabel(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (isSameLocalDay(value, current)) return hourLabel(value);
  return dateTimeLabel(value, now: current, relative: false);
}

/// Encabezado para agrupar por día: `Hoy`, `Ayer`, `Lunes 6 de octubre`,
/// `6 de octubre de 2025`.
String dayHeaderLabel(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final current = now ?? DateTime.now();
  final days = _daysAgo(local, current);
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  final weekday = _weekdaysLong[local.weekday - 1];
  final capitalized = weekday[0].toUpperCase() + weekday.substring(1);
  final dayMonth = '${local.day} de ${_monthsLong[local.month - 1]}';
  if (local.year == current.year) return '$capitalized $dayMonth';
  return '$dayMonth de ${local.year}';
}

/// Fecha larga sin hora: `13 de noviembre de 2026`.
String longDateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.day} de ${_monthsLong[local.month - 1]} de ${local.year}';
}

/// Fecha completa para detalles: `lunes 6 oct 2026 · 14:05`.
String fullDateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${_weekdaysLong[local.weekday - 1]} ${local.day} '
      '${_monthsShort[local.month - 1]} ${local.year} · ${hourLabel(local)}';
}

/// `true` si [a] y [b] caen en el mismo día local.
bool isSameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
