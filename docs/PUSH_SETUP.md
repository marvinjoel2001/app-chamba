# 🔥 Configuración de Push Notifications

## Resumen de cambios hechos

### ✅ Frontend (Flutter)

1. **AndroidManifest.xml** - Canal de notificación y receivers agregados
2. **push_notification_service.dart** - Notificaciones locales en foreground integradas

### ✅ Backend (Node.js)

Archivo ejemplo: `backend-push-example.js` con:
- Envío de notificaciones individuales
- Envío multicast
- Ejemplos de: nueva solicitud, oferta aceptada, mensaje nuevo

---

## 🚀 Para probar las push notifications

### Paso 1: Compilar la app

```bash
flutter clean
flutter pub get
flutter build apk --release --dart-define-from-file=env/dart_define.local.json
```

### Paso 2: Backend - Descargar serviceAccountKey.json

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: `chamba-9f6db`
3. ⚙️ Configuración → Cuentas de servicio
4. Click "Generar nueva clave privada"
5. Descarga y guarda como `serviceAccountKey.json` en tu backend
6. **NO subas este archivo a GitHub**

### Paso 3: Backend - Instalar Firebase Admin

```bash
npm install firebase-admin
```

### Paso 4: Backend - Código de ejemplo

```javascript
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert('./serviceAccountKey.json'),
  projectId: 'chamba-9f6db'
});

// Enviar notificación
async function sendNotification(userToken, title, body) {
  await admin.messaging().send({
    notification: { title, body },
    token: userToken,
    android: {
      priority: 'high',
      notification: {
        channelId: 'chamba_default_channel',
        sound: 'default'
      }
    }
  });
}
```

### Paso 5: Obtener el FCM Token del usuario

Cuando un usuario inicia sesión, la app automáticamente envía el token a tu backend vía:

```javascript
// POST /mobile/push/token
{
  "userId": "...",
  "token": "USER_FCM_TOKEN",
  "platform": "android" // o "ios"
}
```

Guarda este token en tu BD asociado al usuario.

### Paso 6: Enviar notificación de prueba

```javascript
// Token FCM de prueba (obtenlo de los logs de la app)
const testToken = 'dBz...'; // Token del dispositivo

sendNotification(
  testToken,
  '📍 Nueva solicitud',
  'Tienes una solicitud de trabajo cerca'
);
```

---

## 🧪 Testing

### Verificar token en app:
Al iniciar la app, busca en los logs:
```
[PushNotificationService] Token: dBz...
```

### Verificar registro en backend:
Deberías ver en tu BD la tabla/collection `push_tokens` con el token del usuario.

### Enviar notificación:
Desde tu backend, ejecuta la función de ejemplo y verifica que llegue a la app.

---

## 📋 Checklist

- [ ] App compilada y instalada en dispositivo real
- [ ] Backend tiene `serviceAccountKey.json`
- [ ] Backend tiene Firebase Admin instalado
- [ ] Usuario logueado en app (genera y envía token)
- [ ] Token guardado en BD del backend
- [ ] Función de envío implementada en backend
- [ ] Notificación de prueba enviada y recibida

---

## ❌ Problemas comunes

### "Unknown API key" en Cloudinary
- Verifica `dart_define.local.json` tenga las credenciales correctas
- Corre con: `flutter run --dart-define-from-file=env/dart_define.local.json`

### No llegan notificaciones en foreground
- Verifica que `flutter_local_notifications` está inicializado
- Revisa logs: `flutter logs`

### Token no se registra en backend
- Verifica que backend endpoint `/mobile/push/token` existe
- Revisa logs del backend para errores
