/**
 * =========================================================
 * BACKEND - EJEMPLO DE ENVÍO DE NOTIFICACIONES PUSH (FCM)
 * =========================================================
 * 
 * Opción 1: Usando Firebase Admin SDK (Recomendado)
 * Opción 2: Usando la HTTP API directamente
 */

// ========================================================
// OPCIÓN 1: Firebase Admin SDK (Node.js)
// ========================================================

const admin = require('firebase-admin');

// Inicializar con serviceAccountKey.json descargado de Firebase Console
admin.initializeApp({
  credential: admin.credential.cert('./serviceAccountKey.json'),
  projectId: 'chamba-9f6db'
});

/**
 * Enviar notificación a un usuario específico
 * @param {string} fcmToken - Token FCM guardado en tu BD
 * @param {string} title - Título de la notificación
 * @param {string} body - Cuerpo del mensaje
 * @param {object} data - Datos adicionales (opcional)
 */
async function sendPushNotification(fcmToken, title, body, data = {}) {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      sound: 'default',
    },
    token: fcmToken,
    android: {
      priority: 'high',
      notification: {
        channelId: 'chamba_default_channel',
        priority: 'high',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Notificación enviada:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error enviando notificación:', error);
    // Si el token es inválido, eliminarlo de la BD
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log('Token inválido, eliminar de BD:', fcmToken);
      // await removeTokenFromDatabase(fcmToken);
    }
    return { success: false, error: error.message };
  }
}

/**
 * Enviar notificación a múltiples usuarios
 */
async function sendMulticast(tokens, title, body, data = {}) {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    tokens: tokens, // Array de tokens
  };

  const response = await admin.messaging().sendMulticast(message);
  console.log(`Enviadas: ${response.successCount}, Fallidas: ${response.failureCount}`);
  return response;
}

// ========================================================
// OPCIÓN 2: HTTP API sin SDK (CURL o fetch)
// ========================================================

/**
 * Enviar notificación usando cURL
 * 
 * 1. Obtener token de acceso OAuth2:
 *    Ve a: https://developers.google.com/oauthplayground
 *    Selecciona: Firebase Cloud Messaging API v1 → https://www.googleapis.com/auth/firebase.messaging
 *    Autoriza y copia el Access Token
 */

const CURL_EXAMPLE = `
curl -X POST https://fcm.googleapis.com/v1/projects/chamba-9f6db/messages:send \\
  -H 'Authorization: Bearer YOUR_OAUTH2_TOKEN' \\
  -H 'Content-Type: application/json' \\
  -d '{
    "message": {
      "token": "USER_FCM_TOKEN",
      "notification": {
        "title": "Nueva solicitud de trabajo",
        "body": "Tienes una nueva solicitud cerca de tu ubicación"
      },
      "data": {
        "requestId": "12345",
        "type": "new_request",
        "click_action": "FLUTTER_NOTIFICATION_CLICK"
      },
      "android": {
        "priority": "high",
        "notification": {
          "channelId": "chamba_default_channel",
          "sound": "default"
        }
      }
    }
  }'
`;

// ========================================================
// EJEMPLOS DE USO
// ========================================================

// Ejemplo 1: Notificación de nueva solicitud de trabajo
async function notifyNewRequest(workerToken, requestId, clientName, jobType) {
  return sendPushNotification(
    workerToken,
    '📍 Nueva solicitud de trabajo',
    `${clientName} necesita ${jobType}`,
    {
      type: 'new_request',
      requestId: requestId,
      screen: '/incoming-request',
    }
  );
}

// Ejemplo 2: Notificación de oferta aceptada
async function notifyOfferAccepted(workerToken, requestId, amount) {
  return sendPushNotification(
    workerToken,
    '✅ ¡Oferta aceptada!',
    `Tu oferta de Bs ${amount} fue aceptada`,
    {
      type: 'offer_accepted',
      requestId: requestId,
      amount: amount.toString(),
      screen: '/job-progress',
    }
  );
}

// Ejemplo 3: Notificación de mensaje nuevo
async function notifyNewMessage(userToken, senderName, message, threadId) {
  return sendPushNotification(
    userToken,
    `💬 ${senderName}`,
    message,
    {
      type: 'new_message',
      threadId: threadId,
      screen: '/chat',
    }
  );
}

// ========================================================
// CÓMO OBTENER EL SERVICE ACCOUNT KEY
// ========================================================

/**
 * 1. Ve a Firebase Console: https://console.firebase.google.com/
 * 2. Selecciona tu proyecto: chamba-9f6db
 * 3. Ve a ⚙️ Configuración (Settings) → Cuentas de servicio (Service accounts)
 * 4. Click en "Generar nueva clave privada" (Generate new private key)
 * 5. Descarga el archivo JSON y guárdalo como 'serviceAccountKey.json'
 * 6. NO subas este archivo a GitHub (agrega a .gitignore)
 */

module.exports = {
  sendPushNotification,
  sendMulticast,
  notifyNewRequest,
  notifyOfferAccepted,
  notifyNewMessage,
};
