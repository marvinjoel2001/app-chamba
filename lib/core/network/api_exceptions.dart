/// Excepciones tipadas de la capa HTTP.
///
/// `toString()` conserva el formato `Exception: <mensaje>` para que el código
/// existente que hace `error.toString().replaceFirst('Exception: ', '')`
/// siga mostrando el mismo texto, pero ahora `failure_mapper.dart` puede
/// clasificar por TIPO (sin red / timeout / 401 / 5xx) en vez de por texto.
class NetworkException implements Exception {
  const NetworkException(this.message, {this.isTimeout = false});

  final String message;

  /// true si el request se cortó por tiempo de espera (red lenta). En un POST
  /// esto NO garantiza que el servidor no lo haya procesado.
  final bool isTimeout;

  @override
  String toString() => 'Exception: $message';
}

class ApiException implements Exception {
  const ApiException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'Exception: $message';
}
