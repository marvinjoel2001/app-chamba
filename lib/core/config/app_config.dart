import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl => _resolveLocalhost(
    const String.fromEnvironment(
      'API_BASE_URL',
      // defaultValue: 'https://eloquent-vibrancy-production.up.railway.app/api', // Railway (producción)
      defaultValue: 'http://localhost:3001/api',
    ),
  );

  static const String socketNamespace = '/realtime';
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
  static const String cloudinaryApiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '',
  );

  static String get socketBaseUrl => _resolveLocalhost(
    const String.fromEnvironment(
      'SOCKET_BASE_URL',
      // defaultValue: 'https://eloquent-vibrancy-production.up.railway.app', // Railway (producción)
      defaultValue: 'http://localhost:3001',
    ),
  );

  static String _resolveLocalhost(String rawUrl) {
    if (kIsWeb || !Platform.isAndroid) {
      return rawUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl;
    }

    if (uri.host != 'localhost') {
      return rawUrl;
    }

    return uri.replace(host: '10.0.2.2').toString();
  }
}
