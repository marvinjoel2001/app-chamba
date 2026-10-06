import '../network/api_exceptions.dart';
import 'failure.dart';

Failure mapToFailure(Object error) {
  // 1) Clasificación por tipo (fuente de verdad).
  if (error is NetworkException) {
    return NetworkFailure(error.message);
  }
  if (error is ApiException) {
    if (error.isUnauthorized) return UnauthorizedFailure(error.message);
    if (error.statusCode == 400 || error.statusCode == 422) {
      return ValidationFailure(error.message);
    }
    return ServerFailure(error.message);
  }

  // 2) Fallback por texto para errores que no vienen de ApiService
  //    (plugins, sockets, excepciones lanzadas a mano en las pantallas).
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  final lower = message.toLowerCase();

  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('connection') ||
      lower.contains('conexión') ||
      lower.contains('conexion') ||
      lower.contains('conectar') ||
      lower.contains('tiempo de espera')) {
    return NetworkFailure(message.isEmpty ? 'Error de red.' : message);
  }

  if (lower.contains('unauthorized') ||
      lower.contains('token') ||
      lower.contains('sesion') ||
      lower.contains('sesión')) {
    return UnauthorizedFailure(message.isEmpty ? 'No autorizado.' : message);
  }

  if (lower.contains('obligatorio') ||
      lower.contains('invalida') ||
      lower.contains('inválida') ||
      lower.contains('ingresa')) {
    return ValidationFailure(message.isEmpty ? 'Datos inválidos.' : message);
  }

  if (message.isNotEmpty) {
    return ServerFailure(message);
  }

  return const UnknownFailure('Ocurrió un error inesperado.');
}
