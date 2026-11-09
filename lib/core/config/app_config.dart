import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  /// Servidor de producción. Si una versión de la tienda se compila sin
  /// `--dart-define-from-file`, usa este en vez de quedar sin servidor
  /// ("No host specified in URI").
  static const String _productionApi =
      'https://api.chambatrabajo.com/api';
  static const String _productionSocket =
      'https://api.chambatrabajo.com';

  static String get apiBaseUrl => _resolveLocalhost(
        _orProduction(
          const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
          _productionApi,
        ),
      );

  static const String socketNamespace = '/realtime';
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );



  static String get socketBaseUrl => _resolveLocalhost(
        _orProduction(
          const String.fromEnvironment('SOCKET_BASE_URL', defaultValue: ''),
          _productionSocket,
        ),
      );

  /// En release, una URL vacía cae al servidor de producción; en debug se
  /// respeta vacía para notar el olvido al desarrollar.
  @visibleForTesting
  static String orProductionFor(String value, String production,
          {required bool release}) =>
      value.trim().isEmpty && release ? production : value;

  static String _orProduction(String value, String production) =>
      orProductionFor(value, production, release: kReleaseMode);

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
