import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/core/network/realtime_service.dart';
import 'package:mobile/features/worker/data/models/worker_job_model.dart';
import 'package:mobile/features/worker/domain/entities/worker_job.dart';
import 'package:mobile/features/worker/domain/repositories/worker_repository.dart';
import 'package:mobile/features/worker/domain/usecases/worker_usecases.dart';
import 'package:mobile/features/worker/presentation/screens/wallet_screen.dart';

class _SlowRepository extends Fake implements WorkerRepository {
  _SlowRepository(this.jobs);
  List<WorkerJob> jobs;
  Completer<void>? gate;
  @override
  Future<Result<List<WorkerJob>>> workerHistory(
      {required String workerUserId}) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return Success(jobs);
  }
}

class _Repository extends Fake implements WorkerRepository {
  _Repository(this.jobs);
  List<WorkerJob> jobs;
  int calls = 0;
  @override
  Future<Result<List<WorkerJob>>> workerHistory(
      {required String workerUserId}) async {
    calls++;
    return Success(jobs);
  }
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

  testWidgets(
      'returning to wallet refreshes completed work without pressing refresh',
      (tester) async {
    final repo = _Repository([]);
    final useCase = GetWorkerHistoryUseCase(repo);
    Widget screen(bool active) => MaterialApp(
        home: WalletScreen(isActive: active, getWorkerHistoryUseCase: useCase));
    await tester.pumpWidget(screen(true));
    await tester.pump();
    await tester.pumpWidget(screen(false));
    repo.jobs = [job('accepted', 'completed', 110)];
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(find.text('Bs 110.00'), findsWidgets);
    expect(repo.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reconnect refreshes visible wallet but not an inactive tab',
      (tester) async {
    final repo = _Repository([]);
    final useCase = GetWorkerHistoryUseCase(repo);
    Widget screen(bool active) => MaterialApp(
        home: WalletScreen(isActive: active, getWorkerHistoryUseCase: useCase));
    await tester.pumpWidget(screen(true));
    await tester.pump();
    repo.jobs = [job('accepted', 'completed', 220)];
    RealtimeService.instance.reconnectCount.value++;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Bs 220.00'), findsWidgets);
    await tester.pumpWidget(screen(false));
    final calls = repo.calls;
    RealtimeService.instance.reconnectCount.value++;
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.calls, calls);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reloading keeps the previous balance visible until new data',
      (tester) async {
    final repo = _SlowRepository([job('accepted', 'completed', 125)]);
    final useCase = GetWorkerHistoryUseCase(repo);
    Widget screen(bool active) => MaterialApp(
        home: WalletScreen(isActive: active, getWorkerHistoryUseCase: useCase));
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(find.text('Bs 125.00'), findsWidgets);

    repo.gate = Completer<void>();
    repo.jobs = [job('accepted', 'completed', 300)];
    await tester.pumpWidget(screen(false));
    await tester.pumpWidget(screen(true));
    await tester.pump();
    // Mientras la recarga está en curso, el saldo anterior no desaparece.
    expect(find.text('Bs 125.00'), findsWidgets);

    repo.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Bs 300.00'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
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
