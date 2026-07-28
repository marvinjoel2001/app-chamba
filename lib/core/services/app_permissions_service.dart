import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permisos obligatorios por rol.
enum RequiredAppPermission {
  location,
  locationAlways,
  preciseLocation,
  overlay,
  notifications,
  fullScreenIntent,
  batteryUnrestricted,
}

class AppPermissionsService {
  const AppPermissionsService._();

  /// Expuesto por MainActivity: accesos especiales que permission_handler no cubre.
  static const MethodChannel _systemChannel = MethodChannel('chamba/system');

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  static List<RequiredAppPermission> requiredPermissionsForRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'worker') {
      return const [
        RequiredAppPermission.location,
        RequiredAppPermission.locationAlways,
        RequiredAppPermission.preciseLocation,
        RequiredAppPermission.overlay,
        RequiredAppPermission.notifications,
        RequiredAppPermission.fullScreenIntent,
        RequiredAppPermission.batteryUnrestricted,
      ];
    }

    return const [RequiredAppPermission.location];
  }

  static Future<bool> areAllRequiredPermissionsGranted(String role) async {
    final required = requiredPermissionsForRole(role);
    for (final permission in required) {
      if (!await isPermissionGranted(permission)) {
        return false;
      }
    }
    return true;
  }

  static Future<bool> isPermissionGranted(
    RequiredAppPermission permission,
  ) async {
    switch (permission) {
      case RequiredAppPermission.location:
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
        final status = await Geolocator.checkPermission();
        return status == LocationPermission.whileInUse ||
            status == LocationPermission.always;

      case RequiredAppPermission.locationAlways:
        if (!_isAndroid && !_isIOS) {
          return true;
        }
        final status = await Permission.locationAlways.status;
        return status.isGranted;

      case RequiredAppPermission.preciseLocation:
        final hasLocation = await isPermissionGranted(
          RequiredAppPermission.location,
        );
        if (!hasLocation) {
          return false;
        }

        if (_isAndroid) {
          // En Android este estado puede variar por versión del sistema;
          // usamos ACCESS_FINE_LOCATION como validación de ubicación precisa.
          final fineStatus = await Permission.location.status;
          return fineStatus.isGranted;
        }

        final accuracy = await Geolocator.getLocationAccuracy();
        return accuracy == LocationAccuracyStatus.precise ||
            accuracy == LocationAccuracyStatus.unknown;

      case RequiredAppPermission.overlay:
        if (!_isAndroid) {
          return true;
        }
        final status = await Permission.systemAlertWindow.status;
        return status.isGranted;

      case RequiredAppPermission.notifications:
        if (!_isAndroid && !_isIOS) {
          return true;
        }
        final status = await Permission.notification.status;
        return status.isGranted;

      case RequiredAppPermission.fullScreenIntent:
        if (!_isAndroid) {
          return true;
        }
        try {
          final allowed = await _systemChannel.invokeMethod<bool>(
            'canUseFullScreenIntent',
          );
          return allowed ?? true;
        } catch (_) {
          // Canal no disponible (p. ej. isolate sin actividad): no bloquear.
          return true;
        }

      case RequiredAppPermission.batteryUnrestricted:
        if (!_isAndroid) {
          return true;
        }
        final status = await Permission.ignoreBatteryOptimizations.status;
        return status.isGranted;
    }
  }

  static Future<void> requestPermission(
    RequiredAppPermission permission,
  ) async {
    switch (permission) {
      case RequiredAppPermission.location:
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          await Geolocator.openLocationSettings();
          // Try to wait a bit or just assume they might have changed it
          await Future.delayed(const Duration(seconds: 1));
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw Exception('gps_disabled');
          }
        }
        await Geolocator.requestPermission();
        break;

      case RequiredAppPermission.locationAlways:
        if (!_isAndroid && !_isIOS) {
          return;
        }
        await Permission.locationWhenInUse.request();
        await Permission.locationAlways.request();
        break;

      case RequiredAppPermission.preciseLocation:
        await Geolocator.requestPermission();
        break;

      case RequiredAppPermission.overlay:
        if (!_isAndroid) {
          return;
        }
        await Permission.systemAlertWindow.request();
        break;

      case RequiredAppPermission.notifications:
        if (!_isAndroid && !_isIOS) {
          return;
        }
        await Permission.notification.request();
        break;

      case RequiredAppPermission.fullScreenIntent:
        if (!_isAndroid) {
          return;
        }
        try {
          await _systemChannel.invokeMethod<void>(
            'openFullScreenIntentSettings',
          );
        } catch (_) {}
        break;

      case RequiredAppPermission.batteryUnrestricted:
        if (!_isAndroid) {
          return;
        }
        await Permission.ignoreBatteryOptimizations.request();
        break;
    }
  }

  static Future<void> openSettingsFor(RequiredAppPermission permission) async {
    switch (permission) {
      case RequiredAppPermission.location:
        await Geolocator.openLocationSettings();
        await openAppSettings();
        break;

      case RequiredAppPermission.fullScreenIntent:
        await requestPermission(permission);
        break;

      case RequiredAppPermission.locationAlways:
      case RequiredAppPermission.preciseLocation:
      case RequiredAppPermission.overlay:
      case RequiredAppPermission.notifications:
      case RequiredAppPermission.batteryUnrestricted:
        await openAppSettings();
        break;
    }
  }
}
