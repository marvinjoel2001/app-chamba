import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl => _resolveLocalhost(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://eloquent-vibrancy-production.up.railway.app/api',
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

  static String get socketBaseUrl => _resolveLocalhost(
    const String.fromEnvironment(
      'SOCKET_BASE_URL',
      defaultValue: 'https://eloquent-vibrancy-production.up.railway.app',
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
