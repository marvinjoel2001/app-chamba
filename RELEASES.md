# Versiones de la app

Cada versión que se sube a una tienda lleva un **tag** `vX.Y.Z+N` en el commit
desde el que se compila. Así siempre sabes qué código tiene cada build:

```bash
git fetch --tags
git checkout v1.0.2+3
```

| Versión | Tag | Commit | Google Play | App Store | Qué trae |
|---|---|---|---|---|---|
| **1.0.3+4** | `v1.0.3+4` | `40ffaea` | Lista para compilar, **aún no subida** (pasos abajo) | Lista para compilar (ver [docs/publicar-ios.md](docs/publicar-ios.md)) | "Olvidé mi contraseña" con Google; aviso de intentos y bloqueo de 15 min; sin botón "Ya pagué"; las fotos de perfil y de solicitudes las sube el backend (ya no se usa el upload preset sin firma de Cloudinary); solo muestra las modalidades de contratación que el admin deja activas; sin los permisos de fotos y videos (`READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`) que Google Play rechaza; correcciones de la auditoría (20-oct); verificación del teléfono al registrarse (2-nov); proyecto iOS listo. |
| 1.0.2+3 | `v1.0.2+3` | `93f4dec` | **Prueba cerrada**. Google Play no deja enviarla a producción: pide `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` (los agregaba `open_filex`). | — | Compilada con `env/dart_define.prod.json`. No incluye nada de 1.0.3+4. Reemplázala por la 1.0.3+4 en todos los canales. |
| 1.0.1+2 | `v1.0.1+2` | `2ce9d89` | Reemplazada | — | Se compiló sin `--dart-define-from-file` y salió sin `API_BASE_URL`. |
| 1.0.0+1 | — | — | — | — | Antes de llevar este registro (commit exacto desconocido). |

### Crear los tags (una sola vez)

Los tags de la tabla todavía no están en GitHub. Los commits ya están en
`main`; créalos desde tu computadora:

```bash
git fetch origin && git tag -a v1.0.1+2 2ce9d89 -m "1.0.1+2 (reemplazada)" && git tag -a v1.0.2+3 93f4dec -m "1.0.2+3 - Play prueba cerrada" && git tag -a v1.0.3+4 40ffaea -m "1.0.3+4"
```

```bash
git push origin v1.0.1+2 v1.0.2+3 v1.0.3+4
```

## Compatibilidad con el backend

Cuando ya nadie use la 1.0.2+3 (que sube fotos directo a Cloudinary),
desactiva en Cloudinary el upload preset sin firma (Settings → Upload →
Upload presets). Desde la 1.0.3+4 todas las fotos las sube el backend.

La 1.0.3+4 usa `POST /api/auth/password/google/start` y `.../complete`. El
backend que los tiene ya está en `main` de backend-chamba: confirma que Railway
lo desplegó antes de publicar la app. Las versiones 1.0.2+3 y anteriores siguen
funcionando con ese backend.

## Subir la 1.0.3+4 a Google Play

Arregla el aviso "Usar selectores de sistema alternativos para fotos o videos":
la 1.0.3+4 ya no pide `READ_MEDIA_IMAGES` ni `READ_MEDIA_VIDEO` (las fotos se
eligen con el selector del sistema, que no necesita permisos).

1. Necesitas los mismos archivos con los que compilaste la 1.0.2+3 (no están en
   git): `android/key.properties` con su keystore de subida y
   `env/dart_define.prod.json`. Sin `key.properties` el bundle sale firmado con
   la clave de depuración y Google Play lo rechaza.
2. Compila desde `main`:
   ```bash
   git checkout main
   ```
   ```bash
   git pull
   ```
   ```bash
   flutter clean
   ```
   ```bash
   flutter pub get
   ```
   ```bash
   flutter build appbundle --release --dart-define-from-file=env/dart_define.prod.json
   ```
   El archivo queda en `build/app/outputs/bundle/release/app-release.aab`.
3. (Opcional) Confirma que no pide esos permisos con
   [bundletool](https://github.com/google/bundletool/releases): en la salida
   de este comando no debe aparecer `READ_MEDIA_IMAGES` ni `READ_MEDIA_VIDEO`.
   ```bash
   java -jar bundletool.jar dump manifest --bundle build/app/outputs/bundle/release/app-release.aab
   ```
4. En Play Console, Google pide quitar esos permisos de **todos** los canales:
   - **Producción**: en la versión en borrador, quita el paquete 3 (1.0.2) y
     sube `app-release.aab` (4 (1.0.3)).
   - **Prueba cerrada** (y cualquier otro canal que todavía tenga la 3 (1.0.2)):
     crea una versión nueva con el mismo `app-release.aab`.
   - Envía los cambios a revisión. Ya no hace falta declarar permisos de fotos
     y videos.
5. Si Play responde que el código de versión 4 ya se usó, cambia `version:` a
   `1.0.3+5` en `pubspec.yaml` y compila de nuevo.
6. Crea el tag `v1.0.3+4` (comandos de arriba) y actualiza esta tabla.

## Cómo publicar una versión nueva

1. Sube `version:` en `pubspec.yaml`. El número después del `+` (versionCode /
   CFBundleVersion) siempre tiene que ser mayor que el último subido.
2. Compila con la configuración de producción (el archivo no está en git):
   ```bash
   flutter build appbundle --release --dart-define-from-file=env/dart_define.prod.json
   ```
   ```bash
   flutter build ipa --release --dart-define-from-file=env/dart_define.prod.json
   ```
3. Marca el commit con el tag de la versión y súbelo:
   ```bash
   git tag -a v1.0.4+5 -m "1.0.4+5"
   ```
   ```bash
   git push origin v1.0.4+5
   ```
   Si cambias código después de crear el tag y antes de subir el build, mueve el
   tag al commit nuevo (`git tag -fa ...` y `git push -f origin <tag>`).
4. Actualiza esta tabla cuando cambie el estado en la tienda (prueba interna,
   cerrada, producción).
