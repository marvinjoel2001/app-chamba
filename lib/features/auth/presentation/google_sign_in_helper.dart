import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

/// Abre el selector de cuentas de Google y devuelve el idToken, o null si la
/// persona cerró el selector. Lo usan el login y "Olvidé mi contraseña".
Future<String?> requestGoogleIdToken() async {
  final googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleWebClientId.isNotEmpty
        ? AppConfig.googleWebClientId
        : null,
    scopes: const ['email', 'profile'],
  );
  // Limpia sesión previa para evitar conflictos de cache y poder elegir cuenta.
  await googleSignIn.signOut();
  final account = await googleSignIn.signIn();
  if (account == null) return null;

  final auth = await account.authentication;
  if (auth.idToken == null) {
    throw Exception(
      'No se pudo obtener el idToken de Google. '
      'Verifica que GOOGLE_WEB_CLIENT_ID esté configurado correctamente.',
    );
  }
  return auth.idToken;
}

/// Traduce los errores nativos de Google Sign-In a un mensaje entendible.
/// El código 10 (DEVELOPER_ERROR) significa que el paquete + SHA-1 de esta
/// build no están registrados como cliente OAuth Android en Firebase.
String googleSignInErrorMessage(Object error) {
  final raw = error.toString();
  if (raw.contains('ApiException: 10') || raw.contains('DEVELOPER_ERROR')) {
    return 'Google Sign-In no está configurado para esta versión de la app '
        '(falta registrar el SHA-1 en Firebase). Usa correo y contraseña por ahora.';
  }
  if (raw.contains('network_error') || raw.contains('ApiException: 7')) {
    return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
  }
  if (raw.contains('ApiException: 12501') || raw.contains('sign_in_canceled')) {
    return 'Inicio de sesión con Google cancelado.';
  }
  if (raw.contains('sign_in_failed')) {
    return 'No se pudo iniciar sesión con Google. Intenta de nuevo.';
  }
  return raw.replaceAll('Exception: ', '');
}
