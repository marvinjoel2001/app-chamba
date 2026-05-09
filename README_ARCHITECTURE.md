# Clean Architecture (Mobile)

Este proyecto fue reorganizado desde un enfoque feature-first acoplado a servicios directos, hacia Clean Architecture por feature.

## Estructura

```text
lib/
  core/
    errors/        # Failure + Result + mapper + extensiones
    services/      # MobileBackendService (infraestructura compartida)
    usecases/      # base abstractions
  features/
    {feature}/
      domain/
        entities/
        repositories/
        usecases/
      data/
        datasources/
        models/
        repositories/
      presentation/
        screens/
        state/
```

## Reglas aplicadas

1. `domain` no importa `data`.
2. `data` implementa contratos de `domain`.
3. `presentation/screens` ya no llama directamente a `MobileBackendService`.
4. Manejo de errores funcional con `Result<T>` (`Success`/`Error`) y `Failure` tipado.
5. `mobile_data` quedó extraído a `core/services/mobile_backend_service.dart`.

## Flujo estándar

1. Screen invoca UseCase.
2. UseCase depende de Repository (interface en domain).
3. RepositoryImpl usa DataSource remoto.
4. DataSource usa `MobileBackendService`.
5. Repository mapea excepciones a `Failure`.

## Features migradas

- `worker`
- `auth`
- `request`
- `offers`
- `messages`
- `tracking`
- `review`
- `explore` (llamadas de pantalla migradas al patrón)

## Testing

Se agregaron tests unitarios de casos de uso en:

- `test/features/worker/domain/usecases/worker_usecases_test.dart`

Cobertura incluida:

- `GetWorkerHistoryUseCase`
- `SetWorkerAvailabilityUseCase`
- `CreateWorkerCategoryUseCase`
