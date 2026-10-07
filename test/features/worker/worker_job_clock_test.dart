import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/worker/data/models/worker_job_model.dart';

void main() {
  test('historial conserva el tiempo trabajado al guardar y recuperar cache',
      () {
    final job = WorkerJobModel.fromJson({
      'requestId': 'hora',
      'requestStatus': 'completed',
      'amount': 1.43,
      'workElapsedSeconds': 258,
      'completedAt': '2026-10-07T18:28:22Z',
    });
    final restored = WorkerJobModel.fromJson(job.toJson());
    expect(restored.workElapsedSeconds, 258);
    expect(restored.completedAt, job.completedAt);
    expect(restored.amount, 1.43);
  });
  test('servidores antiguos dejan la duración sin inventar un valor', () {
    final job = WorkerJobModel.fromJson(
        {'requestId': 'viejo', 'requestStatus': 'completed'});
    expect(job.workElapsedSeconds, isNull);
  });
}
