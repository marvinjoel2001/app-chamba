import 'failure.dart';

Failure mapToFailure(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  final lower = message.toLowerCase();

  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('connection')) {
    return NetworkFailure(message.isEmpty ? 'Error de red.' : message);
  }

  if (lower.contains('unauthorized') ||
      lower.contains('token') ||
      lower.contains('sesion')) {
    return UnauthorizedFailure(message.isEmpty ? 'No autorizado.' : message);
  }

  if (lower.contains('obligatorio') ||
      lower.contains('invalida') ||
      lower.contains('ingresa')) {
    return ValidationFailure(message.isEmpty ? 'Datos inválidos.' : message);
  }

  if (message.isNotEmpty) {
    return ServerFailure(message);
  }

  return const UnknownFailure('Ocurrió un error inesperado.');
}
