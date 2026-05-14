import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  late final Future<({String termsText, String appVersion})> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadContent();
  }

  Future<({String termsText, String appVersion})> _loadContent() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    final raw = await rootBundle.loadString(
      'assets/legal/chamba_terminos_y_condiciones_v1.txt',
    );

    final normalized = raw.replaceFirst(
      RegExp(
        r'Versi[oó]n\s+1\.0\s+—\s+Vigente desde 2026',
        caseSensitive: false,
      ),
      'Versión $appVersion — Vigente desde 2026',
    );

    return (termsText: normalized, appVersion: appVersion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Términos y Condiciones',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'Uso obligatorio para crear cuenta',
                            style: TextStyle(
                              color: AppTheme.colorMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<({String termsText, String appVersion})>(
                  future: _contentFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No se pudieron cargar los términos.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.colorMuted),
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data;
                    if (data == null) {
                      return const Center(
                        child: Text(
                          'No hay contenido disponible.',
                          style: TextStyle(color: AppTheme.colorMuted),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Versión app: ${data.appVersion}',
                              style: const TextStyle(
                                color: AppTheme.colorPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  data.termsText,
                                  style: const TextStyle(
                                    color: AppTheme.colorText,
                                    height: 1.35,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
