import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/worker/data/models/worker_job_model.dart';
import 'package:mobile/features/worker/domain/entities/worker_job.dart';
import 'package:mobile/features/worker/domain/repositories/worker_repository.dart';
import 'package:mobile/features/worker/domain/usecases/worker_usecases.dart';
import 'package:mobile/features/worker/presentation/screens/wallet_screen.dart';

class _Repository extends Fake implements WorkerRepository {
  _Repository(this.jobs);
  final List<WorkerJob> jobs;
  @override
  Future<Result<List<WorkerJob>>> workerHistory(
          {required String workerUserId}) async =>
      Success(jobs);
}

WorkerJobModel job(String offerStatus, String requestStatus, double amount) =>
    WorkerJobModel.fromJson({
      'requestId': '$offerStatus-$requestStatus',
      'offerStatus': offerStatus,
      'requestStatus': requestStatus,
      'amount': amount,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'paymentMethod': 'Efectivo',
    });

void main() {
  setUp(() => SessionStore.currentUser = const SessionUser(
      id: 'qa-worker',
      type: 'worker',
      firstName: 'QA',
      email: 'qa@example.invalid'));
  tearDown(() => SessionStore.currentUser = null);

  testWidgets('wallet counts only accepted offers on completed work',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: WalletScreen(
      getWorkerHistoryUseCase: GetWorkerHistoryUseCase(_Repository([
        job('accepted', 'completed', 125),
        job('rejected', 'completed', 800),
        job('accepted', 'cancelled', 600),
        job('accepted', 'assigned', 450),
      ])),
    )));
    await tester.pump();
    expect(find.text('Bs 125.00'), findsWidgets);
    expect(find.text('Bs 925.00'), findsNothing);
    expect(find.text('Bs 800.00'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('offer and payment metadata survive model round trips', () {
    final original = job('rejected', 'completed', 800);
    final restored = WorkerJobModel.fromJson(original.toJson());
    expect(restored.offerStatus, 'rejected');
    expect(restored.paymentMethod, 'Efectivo');
    expect(restored.isEarned, isFalse);
    expect(job('accepted', 'completed', 125).isEarned, isTrue);
    expect(WorkerJobModel.fromJson({'requestStatus': 'completed'}).isEarned,
        isFalse);
  });

  testWidgets('empty wallet can return to requests', (tester) async {
    var navigated = false;
    await tester.pumpWidget(MaterialApp(
        home: WalletScreen(
      getWorkerHistoryUseCase: GetWorkerHistoryUseCase(_Repository([])),
      onFindJobs: () => navigated = true,
    )));
    await tester.pump();
    await tester.ensureVisible(find.text('Buscar trabajos'));
    await tester.tap(find.text('Buscar trabajos'));
    expect(navigated, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
