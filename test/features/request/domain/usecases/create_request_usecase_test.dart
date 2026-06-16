import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/request/domain/entities/request_payload_entity.dart';
import 'package:mobile/features/request/domain/repositories/request_repository.dart';
import 'package:mobile/features/request/domain/usecases/request_usecases.dart';

/// Fake que captura los argumentos enviados a [createRequest] para poder
/// verificar que cada modalidad propaga los parámetros correctos. Solo
/// implementamos [createRequest]; el resto del contrato queda cubierto por
/// [Fake] (lanza si se invoca por error).
class _CapturingRequestRepository extends Fake implements RequestRepository {
  _CapturingRequestRepository(this._result);

  final Result<RequestPayloadEntity> _result;

  // Últimos argumentos recibidos.
  String? lastModality;
  double? lastBudget;
  String? lastPriceType;
  int? lastEstimatedHours;
  double? lastHourlyRate;
  int? lastDays;
  double? lastDailyRate;
  String? lastStartDate;
  int createRequestCalls = 0;

  @override
  Future<Result<RequestPayloadEntity>> createRequest({
    required String clientUserId,
    required String title,
    required String description,
    String? category,
    List<Map<String, dynamic>>? aiCategories,
    required double budget,
    required String priceType,
    required String address,
    required double latitude,
    required double longitude,
    String? scheduledAt,
    List<String>? photosBase64,
    List<Map<String, String>>? photos,
    String? paymentMethod,
    String? modality,
    int? estimatedHours,
    double? hourlyRate,
    int? days,
    double? dailyRate,
    String? startDate,
  }) async {
    createRequestCalls++;
    lastModality = modality;
    lastBudget = budget;
    lastPriceType = priceType;
    lastEstimatedHours = estimatedHours;
    lastHourlyRate = hourlyRate;
    lastDays = days;
    lastDailyRate = dailyRate;
    lastStartDate = startDate;
    return _result;
  }
}

void main() {
  const okResult = Success(RequestPayloadEntity(payload: {'id': 'req-1'}));

  group('CreateRequestUseCase modalidades', () {
    test('modalidad por trabajo (fixed) envía el presupuesto cerrado', () async {
      final repo = _CapturingRequestRepository(okResult);
      final usecase = CreateRequestUseCase(repo);

      final result = await usecase(
        clientUserId: 'client-1',
        title: 'Pintar casa',
        description: 'Necesito que pinten mi casa',
        budget: 500,
        priceType: 'fixed',
        address: 'Av. Siempre Viva 123',
        latitude: -17.78,
        longitude: -63.18,
        modality: 'fixed',
      );

      expect(result, isA<Success<RequestPayloadEntity>>());
      expect(repo.createRequestCalls, 1);
      expect(repo.lastModality, 'fixed');
      expect(repo.lastBudget, 500);
      // En precio cerrado no se envían tarifas por hora ni por día.
      expect(repo.lastEstimatedHours, isNull);
      expect(repo.lastHourlyRate, isNull);
      expect(repo.lastDays, isNull);
      expect(repo.lastDailyRate, isNull);
    });

    test('modalidad por hora propaga horas, tarifa y total', () async {
      final repo = _CapturingRequestRepository(okResult);
      final usecase = CreateRequestUseCase(repo);

      const estimatedHours = 4;
      const hourlyRate = 50.0;
      const expectedTotal = estimatedHours * hourlyRate; // 200

      final result = await usecase(
        clientUserId: 'client-1',
        title: 'Pintar casa',
        description: 'Necesito que pinten mi casa',
        budget: expectedTotal,
        priceType: 'hourly',
        address: 'Av. Siempre Viva 123',
        latitude: -17.78,
        longitude: -63.18,
        modality: 'hourly',
        estimatedHours: estimatedHours,
        hourlyRate: hourlyRate,
        startDate: '2026-06-20',
      );

      expect(result, isA<Success<RequestPayloadEntity>>());
      expect(repo.lastModality, 'hourly');
      expect(repo.lastEstimatedHours, 4);
      expect(repo.lastHourlyRate, 50.0);
      expect(repo.lastBudget, 200);
      expect(repo.lastStartDate, '2026-06-20');
      // No deben filtrarse campos de la modalidad por día.
      expect(repo.lastDays, isNull);
      expect(repo.lastDailyRate, isNull);
    });

    test('modalidad por día propaga días, tarifa y total', () async {
      final repo = _CapturingRequestRepository(okResult);
      final usecase = CreateRequestUseCase(repo);

      const days = 3;
      const dailyRate = 120.0;
      const expectedTotal = days * dailyRate; // 360

      final result = await usecase(
        clientUserId: 'client-1',
        title: 'Pintar casa',
        description: 'Necesito que pinten mi casa',
        budget: expectedTotal,
        priceType: 'daily',
        address: 'Av. Siempre Viva 123',
        latitude: -17.78,
        longitude: -63.18,
        modality: 'daily',
        days: days,
        dailyRate: dailyRate,
        startDate: '2026-06-20',
      );

      expect(result, isA<Success<RequestPayloadEntity>>());
      expect(repo.lastModality, 'daily');
      expect(repo.lastDays, 3);
      expect(repo.lastDailyRate, 120.0);
      expect(repo.lastBudget, 360);
      // No deben filtrarse campos de la modalidad por hora.
      expect(repo.lastEstimatedHours, isNull);
      expect(repo.lastHourlyRate, isNull);
    });

    test('propaga el fallo del repositorio sin transformarlo', () async {
      final repo = _CapturingRequestRepository(
        const Error(ValidationFailure('Presupuesto inválido')),
      );
      final usecase = CreateRequestUseCase(repo);

      final result = await usecase(
        clientUserId: 'client-1',
        title: 'Pintar casa',
        description: 'Necesito que pinten mi casa',
        budget: 0,
        priceType: 'fixed',
        address: 'Av. Siempre Viva 123',
        latitude: -17.78,
        longitude: -63.18,
        modality: 'fixed',
      );

      expect(result, isA<Error<RequestPayloadEntity>>());
      expect(repo.createRequestCalls, 1);
    });
  });
}
