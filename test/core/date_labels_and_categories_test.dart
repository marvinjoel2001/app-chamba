import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/category_visuals.dart';
import 'package:mobile/core/utils/date_labels.dart';

void main() {
  // Lunes 12 de octubre de 2026, 15:00 (hora local).
  final now = DateTime(2026, 10, 12, 15, 0);

  group('dateTimeLabel siempre dice de qué día es el aviso', () {
    test('menos de una hora: relativo', () {
      expect(dateTimeLabel(now.subtract(const Duration(seconds: 20)), now: now),
          'Hace un momento');
      expect(dateTimeLabel(now.subtract(const Duration(minutes: 12)), now: now),
          'Hace 12 min');
    });

    test('hoy y ayer incluyen la palabra del día', () {
      expect(dateTimeLabel(DateTime(2026, 10, 12, 9, 5), now: now), 'Hoy, 09:05');
      expect(dateTimeLabel(DateTime(2026, 10, 11, 22, 40), now: now),
          'Ayer, 22:40');
    });

    test('esta semana muestra día de la semana y fecha', () {
      expect(dateTimeLabel(DateTime(2026, 10, 8, 18, 0), now: now),
          'jue 8 oct, 18:00');
    });

    test('más antiguo muestra fecha, y el año si es otro', () {
      expect(dateTimeLabel(DateTime(2026, 9, 1, 7, 30), now: now),
          '1 sep, 07:30');
      expect(dateTimeLabel(DateTime(2025, 12, 24, 20, 0), now: now),
          '24 dic 2025, 20:00');
    });

    test('convierte UTC a hora local', () {
      final utc = DateTime.utc(2026, 10, 12, 12, 0);
      expect(dateTimeLabel(utc, now: now, relative: false),
          contains(hourLabel(utc.toLocal())));
    });
  });

  test('dayHeaderLabel agrupa por día', () {
    expect(dayHeaderLabel(DateTime(2026, 10, 12, 1), now: now), 'Hoy');
    expect(dayHeaderLabel(DateTime(2026, 10, 11, 23), now: now), 'Ayer');
    expect(dayHeaderLabel(DateTime(2026, 10, 6, 10), now: now),
        'Martes 6 de octubre');
  });

  test('messageTimeLabel: solo hora si es de hoy', () {
    expect(messageTimeLabel(DateTime(2026, 10, 12, 8, 3), now: now), '08:03');
    expect(messageTimeLabel(DateTime(2026, 10, 11, 8, 3), now: now),
        'Ayer, 08:03');
  });

  group('CategoryVisual', () {
    test('resuelve por nombre con y sin tildes', () {
      expect(CategoryVisual.of('Plomería').icon, Icons.plumbing_rounded);
      expect(CategoryVisual.of('plomeria').icon, Icons.plumbing_rounded);
      expect(CategoryVisual.of('Electricidad').icon, Icons.bolt_rounded);
      expect(CategoryVisual.of('Carpintería').icon, Icons.carpenter_rounded);
      expect(CategoryVisual.of('Pintura').icon, Icons.format_paint_rounded);
      expect(CategoryVisual.of('Mudanzas y fletes').icon,
          Icons.local_shipping_rounded);
    });

    test('usa el campo icon como pista y cae en General', () {
      expect(CategoryVisual.of('Servicio X', iconHint: 'paint').icon,
          Icons.format_paint_rounded);
      expect(CategoryVisual.of('Algo raro'), CategoryVisual.general);
      expect(CategoryVisual.of(null), CategoryVisual.general);
    });
  });
}
