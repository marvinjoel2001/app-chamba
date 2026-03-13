import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

    return Uri.parse('$normalizedBaseUrl$normalizedPath').replace(
      queryParameters: _normalizeQueryParameters(queryParameters),
    );
  }

  Map<String, String>? _normalizeQueryParameters(
    Map<String, dynamic>? raw,
  ) {
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

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    Exception? lastNetworkError;

    for (final candidate in _candidateBaseUrls()) {
      try {
        final response = await client
            .get(
              _buildUri(candidate, path, queryParameters),
              headers: _jsonHeaders(headers),
            )
            .timeout(_requestTimeout);

        return _parseResponse(response);
      } on TimeoutException {
        lastNetworkError = Exception(
          'Tiempo de espera agotado al conectar con el servidor.',
        );
      } on http.ClientException {
        lastNetworkError = Exception(
          'No se pudo conectar con el servidor. Verifica que el backend este encendido.',
        );
      }
    }

    if (lastNetworkError != null) {
      throw lastNetworkError;
    }

    throw Exception('Error inesperado al conectar con el servidor.');
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    Exception? lastNetworkError;

    for (final candidate in _candidateBaseUrls()) {
      try {
        final response = await client
            .post(
              _buildUri(candidate, path),
              headers: _jsonHeaders(headers),
              body: jsonEncode(body ?? {}),
            )
            .timeout(_requestTimeout);

        return _parseResponse(response);
      } on TimeoutException {
        lastNetworkError = Exception(
          'Tiempo de espera agotado al conectar con el servidor.',
        );
      } on http.ClientException {
        lastNetworkError = Exception(
          'No se pudo conectar con el servidor. Verifica que el backend este encendido.',
        );
      }
    }

    if (lastNetworkError != null) {
      throw lastNetworkError;
    }

    throw Exception('Error inesperado al conectar con el servidor.');
  }

  Map<String, String> _jsonHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      ...?headers,
    };
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
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : _decodeBody(response.body);

    if (response.statusCode >= 400) {
      final bodyMessage = payload['message']?.toString();
      final reason = bodyMessage?.trim().isNotEmpty == true
          ? bodyMessage!.trim()
          : (response.reasonPhrase ?? 'unknown error');
      throw Exception('API error ${response.statusCode}: $reason');
    }

    return payload;
  }
}
