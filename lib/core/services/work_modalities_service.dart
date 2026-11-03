import 'package:flutter/foundation.dart';

import 'mobile_backend_service.dart';

/// Modalidades de contratación que el admin dejó activas. Una apagada no se
/// muestra al crear una solicitud ni en las modalidades del trabajador.
class WorkModalitiesSettings {
  const WorkModalitiesSettings({
    this.fixed = true,
    this.hourly = true,
    this.daily = true,
  });

  /// Todas activas (valor inicial y si el backend no responde).
  static const all = WorkModalitiesSettings();

  factory WorkModalitiesSettings.fromJson(Map<String, dynamic> json) =>
      WorkModalitiesSettings(
        fixed: json['fixed'] != false,
        hourly: json['hourly'] != false,
        daily: json['daily'] != false,
      );

  final bool fixed;
  final bool hourly;
  final bool daily;

  /// 'fixed', 'hourly' o 'daily'. Un valor desconocido se considera activo.
  bool isEnabled(String modality) => switch (modality) {
        'fixed' => fixed,
        'hourly' => hourly,
        'daily' => daily,
        _ => true,
      };
}

/// Consulta las modalidades activas. Se reemplaza en pruebas.
class WorkModalitiesService {
  WorkModalitiesService({Future<Map<String, dynamic>> Function()? fetch})
      : _fetch = fetch ?? MobileBackendService.instance.workModalities;

  final Future<Map<String, dynamic>> Function() _fetch;

  /// Última respuesta buena, para no mostrar opciones apagadas si la red
  /// falla después.
  static WorkModalitiesSettings? _last;

  @visibleForTesting
  static void clearCache() => _last = null;

  /// Si el backend no responde (o es una versión sin este dato) se muestran
  /// todas: el backend igual rechaza una modalidad apagada al crear la
  /// solicitud, con un mensaje claro.
  Future<WorkModalitiesSettings> load() async {
    try {
      final settings = WorkModalitiesSettings.fromJson(await _fetch());
      _last = settings;
      return settings;
    } catch (_) {
      return _last ?? WorkModalitiesSettings.all;
    }
  }
}
