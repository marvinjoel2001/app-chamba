# Chamba Mobile (Flutter)

Flutter starter with clean scalable folder layout and Riverpod state management.

## Features included

- API service layer (`lib/core/network/api_service.dart`)
- Config-based backend URL (`lib/core/config/app_config.dart`)
- Authentication service placeholder
- Riverpod-based auth state controller
- Login and Home screens

## Run

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://web-production-f0db6d.up.railway.app/api \
  --dart-define=SOCKET_BASE_URL=https://web-production-f0db6d.up.railway.app
```

`API_BASE_URL` and `SOCKET_BASE_URL` must be provided; their defaults are empty.

For the production profile in `.vscode/launch.json`, use `env/dart_define.prod.json` (ignored by Git). The current Railway backend is `https://web-production-f0db6d.up.railway.app`; the previous `eloquent-vibrancy-production` address is no longer available.

## Variables locales seguras

Usa un archivo local de defines para no hardcodear tokens:

```bash
cp env/dart_define.example.json env/dart_define.local.json
```

Luego completa tus claves reales en `env/dart_define.local.json` y ejecuta:

```bash
flutter run --dart-define-from-file=env/dart_define.local.json
```

`env/dart_define.local.json` está ignorado por git.

Para subida directa de imágenes a Cloudinary desde la app, agrega:

```json
"CLOUDINARY_CLOUD_NAME": "tu_cloud_name",
"CLOUDINARY_UPLOAD_PRESET": "tu_unsigned_upload_preset"
```

## Optional Firebase push config

When you are ready to enable real push notifications in mobile, add:

```bash
--dart-define=FIREBASE_API_KEY=... \
--dart-define=FIREBASE_APP_ID=... \
--dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
--dart-define=FIREBASE_PROJECT_ID=... \
--dart-define=FIREBASE_STORAGE_BUCKET=...
```

## Structure

- `lib/core`: config + network
- `lib/features/auth`: auth service, state, login screen
- `lib/features/home`: home screen
