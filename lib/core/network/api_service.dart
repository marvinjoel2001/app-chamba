import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/connectivity_service.dart';
import 'api_exceptions.dart';
import '../session/session_credentials.dart';

class ApiService {
  ApiService({required this.baseUrl, required this.client});

  static const Duration _requestTimeout = Duration(seconds: 15);
  final String baseUrl;
  final http.Client client;

  Uri _buildUri(
    String rawBaseUrl,
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) {
    final normalizedBaseUrl = rawBaseUrl.endsWith('/')
        ? rawBaseUrl.substring(0, rawBaseUrl.length - 1)
        : rawBaseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse(
      '$normalizedBaseUrl$normalizedPath',
    ).replace(queryParameters: _normalizeQueryParameters(queryParameters));
  }

  Map<String, String>? _normalizeQueryParameters(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final normalized = <String, String>{};
    raw.forEach((key, value) {
      if (value == null) {
        return;
      }
      normalized[key] = value.toString();
    });

    return normalized.isEmpty ? null : normalized;
  }

  List<String> _candidateBaseUrls() {
    final normalized = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
    final parsed = Uri.tryParse(normalized);

    if (parsed == null ||
        (parsed.host != 'localhost' && parsed.host != '10.0.2.2')) {
      return [baseUrl];
    }

    final currentPort = parsed.port;
    final fallbackPort = currentPort == 3001 ? 3000 : 3001;

    final primary = parsed.replace(port: currentPort).toString();
    final fallback = parsed.replace(port: fallbackPort).toString();

    final suffix = baseUrl.endsWith('/api') ? '/api' : '';
    return ['$primary$suffix', '$fallback$suffix'];
  }

  /// Mensajes pensados para el usuario final (no para el desarrollador).
  static const String _timeoutGetMessage =
      'La conexión está lenta. No pudimos cargar la información, intenta de nuevo.';
  static const String _timeoutPostMessage =
      'La conexión está lenta y no recibimos respuesta. Es posible que tu acción '
      'sí se haya enviado: revisa antes de intentarlo de nuevo.';
  static const String _offlineMessage =
      'No pudimos conectarnos. Revisa tu conexión a internet e intenta de nuevo.';

  /// Reintentos automáticos SOLO para GET (idempotentes). Un POST nunca se
  /// reintenta solo: con red lenta podría duplicar solicitudes/ofertas/pagos.
  static const List<Duration> _getRetryBackoff = [
    Duration(milliseconds: 600),
    Duration(milliseconds: 1800),
  ];

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _send(
          (candidate) => client.get(
            _buildUri(candidate, path, queryParameters),
            headers: _jsonHeaders(headers),
          ),
          timeoutMessage: _timeoutGetMessage,
        );
      } on NetworkException catch (e) {
        // Un timeout ya hizo esperar 15 s al usuario: no multiplicar la espera.
        // Solo se reintentan los cortes rápidos (DNS/socket caído un instante).
        if (e.isTimeout || attempt >= _getRetryBackoff.length) rethrow;
      } on ApiException catch (e) {
        // 502/503/504: el servidor/proxy está despertando o saturado.
        final transient =
            e.statusCode == 502 || e.statusCode == 503 || e.statusCode == 504;
        if (!transient || attempt >= _getRetryBackoff.length) rethrow;
      }
      await Future<void>.delayed(_getRetryBackoff[attempt]);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration timeout = _requestTimeout,
  }) {
    return _send(
      (candidate) => client.post(
        _buildUri(candidate, path),
        headers: _jsonHeaders(headers),
        body: jsonEncode(body ?? {}),
      ),
      timeoutMessage: _timeoutPostMessage,
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(String candidateBaseUrl) request, {
    required String timeoutMessage,
    Duration timeout = _requestTimeout,
  }) async {
    NetworkException? lastNetworkError;

    for (final candidate in _candidateBaseUrls()) {
      final stopwatch = Stopwatch()..start();
      try {
        final response = await request(candidate).timeout(timeout);
        ConnectivityService.instance.reportRequest(
          stopwatch.elapsed,
          failed: false,
        );
        return _parseResponse(response);
      } on TimeoutException {
        ConnectivityService.instance.reportRequest(
          stopwatch.elapsed,
          failed: true,
        );
        lastNetworkError = NetworkException(timeoutMessage, isTimeout: true);
      } on http.ClientException {
        ConnectivityService.instance.reportRequest(
          stopwatch.elapsed,
          failed: true,
        );
        lastNetworkError = const NetworkException(_offlineMessage);
      }
    }

    throw lastNetworkError ?? const NetworkException(_offlineMessage);
  }

  Map<String, String> _jsonHeaders(Map<String, String>? headers) {
    return {...SessionCredentials.headers, ...?headers};
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic> payload;
    try {
      payload = response.body.isEmpty
          ? <String, dynamic>{}
          : _decodeBody(response.body);
    } on FormatException {
      // Respuesta no-JSON (p. ej. HTML de un proxy): no exponer el error crudo.
      payload = <String, dynamic>{};
    }

    if (response.statusCode >= 400) {
      final bodyMessage = _extractBodyMessage(payload);
      throw ApiException(
        _mapHttpErrorMessage(
          statusCode: response.statusCode,
          bodyMessage: bodyMessage,
        ),
        statusCode: response.statusCode,
      );
    }

    return payload;
  }

  String? _extractBodyMessage(Map<String, dynamic> payload) {
    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    final error = payload['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    return null;
  }

  String _mapHttpErrorMessage({required int statusCode, String? bodyMessage}) {
    final message = bodyMessage?.trim();

    if (statusCode == 401) {
      final lower = (message ?? '').toLowerCase();
      if (lower.contains('credencial')) {
        return 'Correo/teléfono o contraseña incorrectos.';
      }
      return 'Tu sesión expiró o no tienes permisos. Inicia sesión nuevamente.';
    }

    if (statusCode == 409) {
      final lower = (message ?? '').toLowerCase();
      if (lower.contains('correo') ||
          lower.contains('email') ||
          lower.contains('telefono') ||
          lower.contains('phone')) {
        return 'El correo o teléfono ya está registrado.';
      }
      return message ??
          'El recurso ya existe. Verifica la información ingresada.';
    }

    if (statusCode == 400) {
      return message ?? 'Revisa los datos ingresados e intenta nuevamente.';
    }

    if (statusCode == 403) {
      return 'No tienes permisos para realizar esta acción.';
    }

    if (statusCode == 404) {
      return 'No se encontró la información solicitada.';
    }

    if (statusCode >= 500) {
      return 'Ocurrió un error en el servidor. Intenta nuevamente en unos minutos.';
    }

    return message ?? 'Ocurrió un error inesperado. Intenta nuevamente.';
  }
}
