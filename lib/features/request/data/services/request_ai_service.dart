import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';

class RequestAiService {
  RequestAiService._();

  static const List<String> supportedCategories = [
    'Construccion',
    'Electricidad',
    'Plomeria',
    'Jardineria',
    'Transporte',
    'Limpieza',
    'Mecanica',
    'Carpinteria',
    'Pintura',
    'General',
  ];

  static const Map<String, String> _categoryIds = {
    'Construccion': 'construccion',
    'Electricidad': 'electricidad',
    'Plomeria': 'plomeria',
    'Jardineria': 'jardineria',
    'Transporte': 'transporte',
    'Limpieza': 'limpieza',
    'Mecanica': 'mecanica',
    'Carpinteria': 'carpinteria',
    'Pintura': 'pintura',
    'General': 'trabajo_general',
  };

  static final http.Client _client = http.Client();

  static Future<String> inferCategory({
    required String description,
    String? title,
  }) async {
    final predictions = await inferCategories(
      description: description,
      title: title,
    );

    if (predictions.isEmpty) {
      return 'General';
    }

    return predictions.first['name']?.toString() ?? 'General';
  }

  static Future<List<Map<String, dynamic>>> inferCategories({
    required String description,
    String? title,
  }) async {
    if (description.trim().isEmpty) {
      return [_fallbackPrediction('General', 0.5)];
    }

    final key = AppConfig.geminiApiKey.trim();
    if (key.isEmpty) {
      return [_fallbackPrediction('General', 0.5)];
    }

    final endpoint = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${AppConfig.geminiModel}:generateContent',
      {'key': key},
    );

    final categoryCatalog = supportedCategories
        .map(
          (name) => '- id: ${_categoryIds[name] ?? 'general'}, nombre: $name',
        )
        .join('\n');

    final prompt =
        '''
Eres un asistente que clasifica solicitudes de trabajo en Bolivia.

Catalogo de categorias permitidas:
$categoryCatalog

Entrada del usuario:
- titulo: ${title ?? ''}
- descripcion: $description

Reglas obligatorias:
1) Devuelve SOLO JSON valido.
2) Formato exacto:
{
  "categorias": [
    { "id": "string", "nombre": "string", "confianza": 0.0 }
  ]
}
3) Ordena por confianza descendente.
4) Maximo 3 categorias.
5) "nombre" debe ser exactamente una categoria del catalogo permitido.
6) Si hay duda, incluye "General".
7) No agregues texto fuera del JSON.
''';

    try {
      final response = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0,
                'responseMimeType': 'application/json',
                'maxOutputTokens': 240,
              },
            }),
          )
          .timeout(const Duration(seconds: 9));

      if (response.statusCode >= 400) {
        return [_fallbackPrediction('General', 0.5)];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        return [_fallbackPrediction('General', 0.5)];
      }

      final first = candidates.first as Map<String, dynamic>?;
      final content = first?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'];
      if (parts is! List || parts.isEmpty) {
        return [_fallbackPrediction('General', 0.5)];
      }

      final text =
          (parts.first as Map<String, dynamic>?)?['text']?.toString().trim() ??
          '';
      if (text.isEmpty) {
        return [_fallbackPrediction('General', 0.5)];
      }

      final rawCategories = _extractRawCategoriesFromModelText(text);
      if (rawCategories.isEmpty) {
        final single = _extractLegacySingleCategory(text);
        return [_fallbackPrediction(single, 0.6)];
      }

      final sanitized = <Map<String, dynamic>>[];
      for (final raw in rawCategories.take(3)) {
        final normalizedName = _normalizeCategoryName(
          raw['nombre']?.toString() ?? raw['category']?.toString() ?? '',
        );
        final confidence = (raw['confianza'] as num?)?.toDouble() ?? 0.5;
        sanitized.add(_fallbackPrediction(normalizedName, confidence));
      }

      sanitized.sort(
        (a, b) => ((b['confidence'] as num?)?.toDouble() ?? 0).compareTo(
          ((a['confidence'] as num?)?.toDouble() ?? 0),
        ),
      );

      return sanitized.isEmpty
          ? [_fallbackPrediction('General', 0.5)]
          : sanitized;
    } on TimeoutException {
      return [_fallbackPrediction('General', 0.5)];
    } catch (_) {
      return [_fallbackPrediction('General', 0.5)];
    }
  }

  static String _normalizeCategoryName(String input) {
    final normalized = input.trim().toLowerCase();

    for (final category in supportedCategories) {
      if (category.toLowerCase() == normalized) {
        return category;
      }
    }

    for (final category in supportedCategories) {
      if (normalized.contains(category.toLowerCase())) {
        return category;
      }
    }

    return 'General';
  }

  static Map<String, dynamic> _fallbackPrediction(
    String name,
    double confidence,
  ) {
    final normalizedName = _normalizeCategoryName(name);
    return {
      'id': _categoryIds[normalizedName] ?? 'trabajo_general',
      'name': normalizedName,
      'confidence': confidence.clamp(0.0, 1.0),
    };
  }

  static List<Map<String, dynamic>> _extractRawCategoriesFromModelText(
    String text,
  ) {
    final trimmed = text.trim();

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(trimmed);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    } catch (_) {}

    if (decoded == null) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final snippet = trimmed.substring(start, end + 1);
        try {
          final raw = jsonDecode(snippet);
          if (raw is Map<String, dynamic>) {
            decoded = raw;
          }
        } catch (_) {}
      }
    }

    if (decoded == null) {
      return const [];
    }

    final categories = decoded['categorias'];
    if (categories is! List) {
      return const [];
    }

    return categories.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static String _extractLegacySingleCategory(String text) {
    final trimmed = text.trim();

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final category = decoded['category']?.toString().trim();
        if (category != null && category.isNotEmpty) {
          return _normalizeCategoryName(category);
        }
      }
    } catch (_) {}

    return _normalizeCategoryName(
      trimmed.split(RegExp(r'[\n\r,.]')).first.trim(),
    );
  }
}
