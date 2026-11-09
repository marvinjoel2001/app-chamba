#!/usr/bin/env bash
# Compila el .aab para Google Play SIEMPRE con la configuración de producción
# y la llave de carga. Uso:  bash scripts/build-play.sh
#
# Evita el error "No host specified in URI": pasa si se compila sin
# --dart-define-from-file (sin servidor, sin Google, sin fotos).
set -euo pipefail
cd "$(dirname "$0")/.."

DEFINES="env/dart_define.prod.json"
FLUTTER="${FLUTTER:-flutter}"

if [[ ! -f "$DEFINES" ]]; then
  echo "Falta $DEFINES (configuración de producción)." >&2
  exit 1
fi
for key in API_BASE_URL SOCKET_BASE_URL GOOGLE_WEB_CLIENT_ID CLOUDINARY_CLOUD_NAME CLOUDINARY_UPLOAD_PRESET; do
  if ! grep -Eq "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$DEFINES"; then
    echo "$DEFINES no tiene $key." >&2
    exit 1
  fi
done
if grep -Eq '"API_BASE_URL"[^,]*(localhost|10\.0\.2\.2|127\.0\.0\.1)' "$DEFINES"; then
  echo "API_BASE_URL apunta a una máquina local; usa el servidor de producción." >&2
  exit 1
fi

# Play solo acepta la llave de carga registrada (Firma de apps en Play Console).
if [[ ! -f android/key.properties ]]; then
  echo "Falta android/key.properties: sin la llave de carga, Play rechaza el .aab." >&2
  echo "Copia android/key.properties.example y apunta storeFile a tu .jks." >&2
  exit 1
fi

"$FLUTTER" build appbundle --release --dart-define-from-file="$DEFINES"

AAB=build/app/outputs/bundle/release/app-release.aab
echo
echo "Listo: $AAB"
echo "Versión: $(grep -E '^version:' pubspec.yaml | cut -d' ' -f2)"
