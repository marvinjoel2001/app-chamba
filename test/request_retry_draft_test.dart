import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/request/domain/entities/request_retry_draft.dart';
import 'package:mobile/features/request/presentation/screens/request_form_screen.dart';

void main() {
  final base = <String, dynamic>{
    'title': 'Puerta',
    'description': 'Reparar puerta',
    'category': 'Carpintería',
    'budget': 100,
    'amount': 120,
    'modality': 'fixed',
    'address': 'Casa',
    'latitude': -17.8,
    'longitude': -63.18
  };
  test(
      'retry uses the original budget rather than the cancelled worker counteroffer',
      () {
    final draft = RequestRetryDraft.fromRequest(base);
    expect(draft.budget, 100);
    expect(draft.description, 'Reparar puerta');
    expect(draft.category, 'Carpintería');
    expect(draft.latitude, -17.8);
  });
  test('hourly and daily retries preserve units and rate', () {
    final hourly = RequestRetryDraft.fromRequest(
        {...base, 'modality': 'hourly', 'estimatedHours': 3, 'hourlyRate': 40});
    expect(hourly.estimatedHours, 3);
    expect(hourly.hourlyRate, 40);
    final daily = RequestRetryDraft.fromRequest(
        {...base, 'modality': 'daily', 'days': 2, 'dailyRate': 150});
    expect(daily.days, 2);
    expect(daily.dailyRate, 150);
  });
  test(
      'older server tracking provides the original destination instead of worker location',
      () {
    final draft = RequestRetryDraft.fromRequest(
        {...base, 'latitude': null, 'longitude': null},
        destination: {'latitude': -16.5, 'longitude': -68.1});
    expect(draft.latitude, -16.5);
    expect(draft.longitude, -68.1);
  });
  test(
      'incomplete or non-finite terms must not silently become another price or modality',
      () {
    for (final change in <Map<String, dynamic>>[
      {'modality': 'hourly', 'estimatedHours': 1.5, 'hourlyRate': 20},
      {'budget': double.nan},
      {'modality': 'unknown'},
      {'modality': 'hourly', 'estimatedHours': 0, 'hourlyRate': 20},
      {'modality': 'daily', 'days': 2, 'dailyRate': -1},
    ]) {
      expect(() => RequestRetryDraft.fromRequest({...base, ...change}),
          throwsFormatException);
    }
  });
  test('legacy hourly pricing must not silently become fixed', () {
    final draft = RequestRetryDraft.fromRequest({
      ...base,
      'modality': null,
      'priceType': 'Por hora',
      'estimatedHours': 2,
      'hourlyRate': 20
    });
    expect(draft.modality, 'hourly');
  });

  test('precarga montos sin .0 sobrante', () {
    expect(formatInitialAmount(100), '100');
    expect(formatInitialAmount(24.5), '24.5');
    expect(formatInitialAmount(0.41), '0.41');
  });

  group('buscar otro trabajador conserva fecha y materiales', () {
    final now = DateTime(2026, 11, 9, 14, 0);
    Map<String, dynamic> daily(String? start) => {
          ...base,
          'modality': 'daily',
          'days': 1,
          'dailyRate': 150,
          'startDate': start,
          'materialsMode': 'worker',
        };

    test('fecha y hora futuras se mantienen tal cual', () {
      final draft = RequestRetryDraft.fromRequest(
          daily('2026-11-10T08:00:00'),
          now: now);
      expect(draft.startDate, '2026-11-10T08:00:00');
      expect(draft.materialsMode, 'worker');
    });

    test('sin hora elegida también se mantiene la fecha', () {
      expect(
          RequestRetryDraft.fromRequest(daily('2026-11-12'), now: now)
              .startDate,
          '2026-11-12');
    });

    test('un día pasado no se copia; hoy sí', () {
      expect(
          RequestRetryDraft.fromRequest(daily('2026-11-08T08:00:00'), now: now)
              .startDate,
          isNull);
      expect(RequestRetryDraft.fromRequest(daily(null), now: now).startDate,
          isNull);
      // Hoy con hora futura o sin hora: se mantiene.
      expect(
          RequestRetryDraft.fromRequest(daily('2026-11-09T14:30:00'), now: now)
              .startDate,
          '2026-11-09T14:30:00');
      expect(
          RequestRetryDraft.fromRequest(daily('2026-11-09'), now: now)
              .startDate,
          '2026-11-09');
      // Hoy con la hora ya pasada: queda solo el día.
      expect(
          RequestRetryDraft.fromRequest(daily('2026-11-09T08:00:00'), now: now)
              .startDate,
          '2026-11-09');
    });

    test('conserva método de pago, fotos y todas las categorías', () {
      final draft = RequestRetryDraft.fromRequest({
        ...daily(null),
        'paymentMethod': 'QR',
        'video': {'url': 'https://res.cloudinary.com/x/v.mp4', 'thumbnailUrl': null},
        'photos': [
          {'id': 'p1', 'url': 'https://res.cloudinary.com/x/a.jpg'},
          {'id': 'p2', 'url': ''},
        ],
        'aiCategories': [
          {'id': 'c1', 'name': 'Plomería', 'confidence': 0.9},
          {'id': 'c2', 'name': 'Albañilería', 'confidence': 0.4},
        ],
      }, now: now);
      expect(draft.paymentMethod, 'QR');
      expect(draft.videoUrl, 'https://res.cloudinary.com/x/v.mp4');
      expect(draft.videoThumbnailUrl, isNull);
      expect(draft.photoUrls, ['https://res.cloudinary.com/x/a.jpg']);
      expect(draft.categories.map((c) => c['name']), ['Plomería', 'Albañilería']);
    });
  });
}
