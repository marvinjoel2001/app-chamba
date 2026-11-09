import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';

/// Misma configuración de idioma que ChambaApp.
Widget spanishApp(Widget Function(BuildContext) builder) => MaterialApp(
      locale: chambaLocale,
      supportedLocales: const [chambaLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(builder: (context) => Scaffold(body: builder(context))),
    );

void main() {
  testWidgets('el calendario sale en español', (tester) async {
    await tester.pumpWidget(spanishApp((context) => TextButton(
          onPressed: () => showDatePicker(
            context: context,
            initialDate: DateTime(2026, 11, 10),
            firstDate: DateTime(2026, 11, 1),
            lastDate: DateTime(2026, 12, 31),
          ),
          child: const Text('abrir'),
        )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.textContaining('noviembre'), findsWidgets);
  });

  testWidgets('el reloj sale en español', (tester) async {
    await tester.pumpWidget(spanishApp((context) => TextButton(
          onPressed: () => showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 8, minute: 0),
          ),
          child: const Text('abrir'),
        )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
