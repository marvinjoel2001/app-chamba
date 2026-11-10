import 'package:mobile/core/push/new_request_burst.dart';
import 'package:mobile/core/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aviso de conexión lenta', () {
    final service = ConnectivityService.instance;
    const fast = Duration(milliseconds: 300);
    const slow = Duration(seconds: 6);

    setUp(service.resetSlowTracking);
    tearDown(service.resetSlowTracking);

    test('un solo request fallido no avisa', () {
      service.reportRequest(fast, failed: true);
      expect(service.isSlow.value, isFalse);
    });

    test('dos fallidos seguidos sí avisan', () {
      service.reportRequest(fast, failed: true);
      service.reportRequest(fast, failed: true);
      expect(service.isSlow.value, isTrue);
    });

    test('dos lentos no avisan, tres sí', () {
      service.reportRequest(slow, failed: false);
      service.reportRequest(slow, failed: false);
      expect(service.isSlow.value, isFalse);
      service.reportRequest(slow, failed: false);
      expect(service.isSlow.value, isTrue);
    });

    test('una respuesta rápida corta la racha de lentos', () {
      service.reportRequest(slow, failed: false);
      service.reportRequest(slow, failed: false);
      service.reportRequest(fast, failed: false);
      service.reportRequest(slow, failed: false);
      expect(service.isSlow.value, isFalse);
    });

    test('subir un archivo que tarda no cuenta como lento', () {
      for (var i = 0; i < 5; i++) {
        service.reportRequest(
          const Duration(seconds: 40),
          failed: false,
          expectedSlow: true,
        );
      }
      expect(service.isSlow.value, isFalse);
    });

    test('dos respuestas rápidas quitan el aviso sin esperar', () {
      service.reportRequest(fast, failed: true);
      service.reportRequest(fast, failed: true);
      expect(service.isSlow.value, isTrue);
      service.reportRequest(fast, failed: false);
      expect(service.isSlow.value, isTrue);
      service.reportRequest(fast, failed: false);
      expect(service.isSlow.value, isFalse);
    });
  });

  group('Aviso de varias solicitudes a la vez', () {
    final t0 = DateTime(2026, 11, 10, 12);

    test('la primera solicitud conserva su propio aviso', () {
      final burst = NewRequestBurst();
      expect(burst.add(scheduled: false, now: t0), isNull);
    });

    test('tres seguidas se anuncian juntas, separando las programadas', () {
      final burst = NewRequestBurst();
      burst.add(scheduled: false, now: t0);
      burst.add(scheduled: false, now: t0.add(const Duration(seconds: 1)));
      final notice =
          burst.add(scheduled: true, now: t0.add(const Duration(seconds: 2)));
      expect(notice!.title, '3 trabajos nuevos');
      expect(notice.body, '2 para hoy y 1 programado. Toca para verlos.');
    });

    test('solo programadas', () {
      final burst = NewRequestBurst();
      burst.add(scheduled: true, now: t0);
      final notice =
          burst.add(scheduled: true, now: t0.add(const Duration(seconds: 1)));
      expect(notice!.body, '2 programados. Toca para verlos.');
    });

    test('pasada la ventana empieza una tanda nueva', () {
      final burst = NewRequestBurst();
      burst.add(scheduled: false, now: t0);
      expect(
        burst.add(scheduled: false, now: t0.add(const Duration(seconds: 30))),
        isNull,
      );
    });
  });
}
