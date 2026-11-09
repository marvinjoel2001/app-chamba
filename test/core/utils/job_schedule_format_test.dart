import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/job_schedule_format.dart';
import 'package:mobile/core/widgets/scheduled_start_badge.dart';

void main() {
  final now = DateTime(2026, 11, 9, 21, 30);

  group('isJobForLaterDay', () {
    test('mañana o después: todavía no va en camino', () {
      expect(isJobForLaterDay('2026-11-10T08:00:00', now: now), isTrue);
      expect(isJobForLaterDay('2026-11-14', now: now), isTrue);
    });

    test('hoy, aunque sea más tarde, ya es el día del trabajo', () {
      expect(isJobForLaterDay('2026-11-09T23:00:00', now: now), isFalse);
      expect(isJobForLaterDay('2026-11-09', now: now), isFalse);
    });

    test('días pasados o sin fecha no cuentan como programados', () {
      expect(isJobForLaterDay('2026-11-08T08:00:00', now: now), isFalse);
      expect(isJobForLaterDay(null, now: now), isFalse);
      expect(isJobForLaterDay('', now: now), isFalse);
    });
  });

  test('scheduledStartSentence pone "mañana" en minúscula', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final raw =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}T08:00:00';
    expect(scheduledStartSentence(raw), 'Empieza mañana 08:00');
  });
}
