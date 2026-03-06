import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';

class ChambaApp extends StatelessWidget {
  const ChambaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chamba',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
