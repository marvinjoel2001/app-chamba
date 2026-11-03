#!/usr/bin/env python3
"""Deja Info.plist alineado con ios/Runner/GoogleService-Info.plist.

Google Sign-In y la verificación de teléfono de Firebase (reCAPTCHA) necesitan
dos URL schemes que salen del GoogleService-Info.plist:
  - REVERSED_CLIENT_ID  (Google Sign-In)
  - app-<GOOGLE_APP_ID con ":" cambiados por "-">  (Firebase Phone Auth)

Úsalo cada vez que reemplaces el GoogleService-Info.plist (por ejemplo después
de `flutterfire configure`):

    python3 ios/scripts/sync_firebase_ios.py

Avisa (y sale con código 1) si el plist es de otro bundle id que el de la app.
"""
import plistlib
import re
import sys
from pathlib import Path

IOS = Path(__file__).resolve().parents[1]
GOOGLE_PLIST = IOS / 'Runner' / 'GoogleService-Info.plist'
INFO_PLIST = IOS / 'Runner' / 'Info.plist'
PBXPROJ = IOS / 'Runner.xcodeproj' / 'project.pbxproj'


def app_bundle_id() -> str:
    ids = set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([\w.\-]+);', PBXPROJ.read_text()))
    ids = {i for i in ids if not i.endswith('.RunnerTests')}
    if len(ids) != 1:
        sys.exit(f'No se pudo leer un único bundle id del proyecto: {sorted(ids)}')
    return ids.pop()


def main() -> int:
    with GOOGLE_PLIST.open('rb') as f:
        google = plistlib.load(f)
    with INFO_PLIST.open('rb') as f:
        info = plistlib.load(f)

    reversed_client_id = google.get('REVERSED_CLIENT_ID')
    google_app_id = google.get('GOOGLE_APP_ID')
    if not reversed_client_id or not google_app_id:
        sys.exit('El GoogleService-Info.plist no tiene REVERSED_CLIENT_ID o GOOGLE_APP_ID: '
                 'activa Google Sign-In en Firebase y descárgalo de nuevo.')

    info['CFBundleURLTypes'] = [
        {
            'CFBundleTypeRole': 'Editor',
            'CFBundleURLName': 'google-sign-in',
            'CFBundleURLSchemes': [reversed_client_id],
        },
        {
            'CFBundleTypeRole': 'Editor',
            'CFBundleURLName': 'firebase-phone-auth',
            'CFBundleURLSchemes': ['app-' + google_app_id.replace(':', '-')],
        },
    ]
    with INFO_PLIST.open('wb') as f:
        plistlib.dump(info, f, sort_keys=False)
    print(f'Info.plist actualizado: {reversed_client_id} y app-{google_app_id.replace(":", "-")}')

    expected = app_bundle_id()
    if google.get('BUNDLE_ID') != expected:
        print(
            f'\nATENCIÓN: el GoogleService-Info.plist es de "{google.get("BUNDLE_ID")}" y la app es '
            f'"{expected}".\nRegistra en Firebase una app iOS con "{expected}", ejecuta '
            f'`flutterfire configure` (o reemplaza el plist) y vuelve a correr este script.\n'
            'Hasta entonces fallan en iOS: push, Google Sign-In y la verificación por SMS.',
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
