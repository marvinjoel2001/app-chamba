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
  --dart-define=API_BASE_URL=http://localhost:3000/api \
  --dart-define=SOCKET_BASE_URL=http://localhost:3000
```

If `API_BASE_URL` is not provided, default is `http://localhost:3000/api`.

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
