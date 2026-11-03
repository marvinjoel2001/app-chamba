# Publicar Chamba en iOS

El proyecto de Xcode ya está listo: bundle id `com.chambatrabajo.app` (el mismo
de Android), equipo `VCLPZYHJ77`, notificaciones push (`Runner.entitlements`),
permisos con textos que explican para qué se usan, tarea en segundo plano de
`flutter_background_service`, permisos de ubicación y notificaciones activados
en `permission_handler` (Podfile) y `ITSAppUsesNonExemptEncryption = NO`.

Lo que falta depende de tus cuentas de Firebase y Apple. Hazlo en este orden.

## 1. Firebase: registrar la app iOS con el bundle id nuevo

El `GoogleService-Info.plist` y `lib/firebase_options.dart` actuales son de una
app iOS registrada como `com.example.mobile`. Firebase no permite cambiar el
bundle id de una app ya creada, así que hay que agregar otra:

1. Firebase Console → proyecto `chamba-9f6db` → Configuración del proyecto →
   **Agregar app** → iOS → bundle id `com.chambatrabajo.app`.
2. Desde la carpeta de la app, regenera la configuración:
   ```bash
   flutterfire configure --project=chamba-9f6db --platforms=android,ios --ios-bundle-id=com.chambatrabajo.app --android-package-name=com.chambatrabajo.app
   ```
   Esto reemplaza `ios/Runner/GoogleService-Info.plist` y la parte iOS de
   `lib/firebase_options.dart`.
3. Copia al `Info.plist` los dos URL schemes del plist nuevo (Google Sign-In y
   verificación por SMS):
   ```bash
   python3 ios/scripts/sync_firebase_ios.py
   ```
   Si el script avisa que el plist es de otro bundle id, el paso 2 no se hizo.

Hasta completar este paso, en iOS no funcionan las notificaciones push, el
inicio de sesión con Google ni la verificación del teléfono por SMS.

## 2. Notificaciones push (APNs)

1. Apple Developer → Certificates, IDs & Profiles → **Keys** → crea una llave
   con *Apple Push Notifications service (APNs)* y descarga el `.p8`.
2. Firebase → Configuración del proyecto → **Cloud Messaging** → app iOS →
   sube la llave `.p8` con su Key ID y tu Team ID (`VCLPZYHJ77`).

La verificación por SMS de Firebase también usa APNs; sin la llave cae al
reCAPTCHA en el navegador.

## 3. Xcode

1. `cd ios && pod install` (o `flutter build ios` lo hace solo).
2. Abre `ios/Runner.xcworkspace` → target Runner → **Signing & Capabilities**:
   confirma el equipo y que aparezcan *Push Notifications* y *Background Modes*
   (Location updates, Background fetch, Remote notifications). Con firma
   automática Xcode crea el App ID `com.chambatrabajo.app`.

## 4. App Store Connect

1. Crea la app con el bundle id `com.chambatrabajo.app`.
2. **Privacidad de la app**: declara ubicación (precisa, también en segundo
   plano para trabajadores), nombre, correo, teléfono, fotos (perfil, trabajos,
   carnet y selfie de verificación) e identificadores del dispositivo (push).
3. **Notas para la revisión**: explica que los trabajadores comparten la
   ubicación en segundo plano para recibir trabajos cercanos y que el cliente
   vea el recorrido. Crea una cuenta de prueba (cliente y trabajador
   verificado) con contraseña fuerte y escríbela en las notas: Apple siempre
   pide una para apps con inicio de sesión. No uses las antiguas cuentas demo.
4. Borrado de cuenta: ya existe en la app (Perfil → Configuración de la cuenta
   → "Eliminar mi cuenta"), que Apple exige.

## 5. Compilar y subir

```bash
flutter build ipa --release --dart-define-from-file=env/dart_define.prod.json
```

Sube `build/ios/ipa/*.ipa` con la app **Transporter** o desde Xcode → Organizer.
Después crea el tag de la versión (ver `RELEASES.md`).

## Riesgo de rechazo: "Iniciar sesión con Apple" (guía 4.8)

Apple pide que, si una app ofrece inicio de sesión con Google, también ofrezca
una opción equivalente que proteja la privacidad (en la práctica, *Iniciar
sesión con Apple*). La app todavía no la tiene. Si la revisión lo pide, hay
que agregarla en la app y en el backend, o quitar el botón de Google en iOS.
