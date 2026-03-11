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

  static final http.Client _client = http.Client();

  static Future<String> inferCategory({
    required String description,
    String? title,
  }) async {
    if (description.trim().isEmpty) {
      return 'General';
    }

    final key = AppConfig.geminiApiKey.trim();
    if (key.isEmpty) {
      return 'General';
    }

    final endpoint = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${AppConfig.geminiModel}:generateContent',
      {'key': key},
    );

    final prompt = '''
Clasifica la solicitud de trabajo en exactamente una categoria de esta lista:
${supportedCategories.join(', ')}.
Responde SOLO con la categoria, sin explicaciones.
Si no estas seguro, responde General.

Titulo: ${title ?? ''}
Descripcion: $description
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
                'maxOutputTokens': 8,
              },
            }),
          )
          .timeout(const Duration(seconds: 9));

      if (response.statusCode >= 400) {
        return 'General';
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        return 'General';
      }

      final first = candidates.first as Map<String, dynamic>?;
      final content = first?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'];
      if (parts is! List || parts.isEmpty) {
        return 'General';
      }

      final text = (parts.first as Map<String, dynamic>?)?['text']?.toString().trim() ?? '';
      if (text.isEmpty) {
        return 'General';
      }

      final normalized = text
          .split(RegExp(r'[\n\r,.]'))
          .first
          .trim()
          .toLowerCase();

      for (final category in supportedCategories) {
        if (category.toLowerCase() == normalized) {
          return category;
        }
      }

      return supportedCategories.firstWhere(
        (category) => normalized.contains(category.toLowerCase()),
        orElse: () => 'General',
      );
    } on TimeoutException {
      return 'General';
    } catch (_) {
      return 'General';
    }
  }
}

