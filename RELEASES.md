# Versiones de la app

Cada versión que se sube a una tienda lleva un **tag** `vX.Y.Z+N` en el commit
desde el que se compila. Así siempre sabes qué código tiene cada build:

```bash
git fetch --tags
git checkout v1.0.2+3
```

| Versión | Tag | Google Play | App Store | Qué trae |
|---|---|---|---|---|
| **1.0.3+4** | `v1.0.3+4` | Lista para compilar, **aún no subida** | Lista para compilar (ver [docs/publicar-ios.md](docs/publicar-ios.md)) | "Olvidé mi contraseña" con Google; aviso de intentos y bloqueo de 15 min; sin botón "Ya pagué"; correcciones de la auditoría (20-oct); verificación del teléfono al registrarse (2-nov); proyecto iOS listo. |
| 1.0.2+3 | `v1.0.2+3` | **Prueba cerrada** | — | Compilada con `env/dart_define.prod.json`. No incluye nada de 1.0.3+4. |
| 1.0.1+2 | `v1.0.1+2` | Reemplazada | — | Se compiló sin `--dart-define-from-file` y salió sin `API_BASE_URL`. |
| 1.0.0+1 | — | — | — | Antes de llevar este registro (commit exacto desconocido). |

## Compatibilidad con el backend

La 1.0.3+4 usa `POST /api/auth/password/google/start` y `.../complete`. Despliega
primero el backend que los tiene (rama `claude/serene-clarke-koq9nk` de
backend-chamba: Railway lo publica al fusionarla a `main`) y después sube la
app. Las versiones 1.0.2+3 y anteriores siguen funcionando con ese backend.

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
