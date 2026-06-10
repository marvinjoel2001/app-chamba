import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';

class ChambaApp extends StatelessWidget {
  const ChambaApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
