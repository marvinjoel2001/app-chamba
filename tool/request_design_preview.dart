// Standalone visual QA entry point. No session is loaded, so publication
// cannot create a request. The production application still uses lib/main.dart.
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/request/presentation/screens/request_form_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    home: Builder(
        builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Vista de diseño · QA')),
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final mode in ['daily', 'hourly', 'fixed'])
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RequestFormScreen(
                            initialPrompt:
                                'PRUEBA DE DISEÑO. No es un servicio real.',
                            modality: mode,
                            initialLatitude: -17.7833,
                            initialLongitude: -63.1821,
                            initialAddress:
                                'Avenida Santos Dumont, Santa Cruz de la Sierra',
                          ),
                        )),
                        child: Text(mode),
                      )),
              ])),
            )),
  ));
}
