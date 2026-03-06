import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/firebase_config.dart';

class PushNotificationService {
  const PushNotificationService();

  Future<void> initialize() async {
    if (!FirebaseConfig.isConfigured) {
      return;
    }

    await Firebase.initializeApp(options: FirebaseConfig.options);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.getToken();
  }
}
