import 'dart:async';

import 'package:flutter/material.dart';

import 'core/network/realtime_service.dart';
import 'core/session/session_credentials.dart';
import 'core/session/session_store.dart';
import 'features/auth/presentation/screens/login_screen.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';

class ChambaApp extends StatefulWidget {
  const ChambaApp({super.key});

  static final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<ChambaApp> createState() => _ChambaAppState();
}

class _ChambaAppState extends State<ChambaApp> {
  bool _handlingExpiration = false;

  @override
  void initState() {
    super.initState();
    SessionCredentials.sessionExpirations.addListener(_onSessionExpired);
  }

  void _onSessionExpired() {
    if (_handlingExpiration) return;
    _handlingExpiration = true;
    unawaited(_returnToLogin());
  }

  Future<void> _returnToLogin() async {
    try {
      RealtimeService.instance.disconnect();
      await SessionStore.clear();
    } finally {
      if (mounted && SessionCredentials.accessToken == null) {
        ChambaApp.navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
      _handlingExpiration = false;
    }
  }

  @override
  void dispose() {
    SessionCredentials.sessionExpirations.removeListener(_onSessionExpired);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ChambaApp.navigatorKey,
      navigatorObservers: [ChambaApp.routeObserver],
      title: 'Chamba',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      theme: AppTheme.dark(),
      builder: (context, child) =>
          OfflineBannerHost(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}
