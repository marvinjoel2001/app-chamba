import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService({required this.baseUrl, required this.client});

  final String baseUrl;
  final http.Client client;

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBaseUrl$normalizedPath').replace(
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await client.get(
      _buildUri(path, queryParameters),
      headers: _jsonHeaders(headers),
    );

    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await client.post(
      _buildUri(path),
      headers: _jsonHeaders(headers),
      body: jsonEncode(body ?? {}),
    );

    return _parseResponse(response);
  }

  Map<String, String> _jsonHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception(
        'API error ${response.statusCode}: ${response.reasonPhrase ?? 'unknown error'}',
      );
    }

    if (response.body.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }
}
