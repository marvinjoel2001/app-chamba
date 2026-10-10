import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/chamba_widgets.dart';

void main() {
  Future<void> showButton(WidgetTester tester, Widget button,
      {double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(child: SizedBox(width: 280, child: button)),
        ),
      ),
    ));
  }

  for (final primary in [true, false]) {
    testWidgets('button $primary fits a long label at text scale 2',
        (tester) async {
      const label = 'Confirmar llegada al lugar de trabajo';
      await showButton(
        tester,
        primary
            ? ChambaPrimaryButton(label: label, icon: Icons.check, onPressed: () {})
            : ChambaSecondaryButton(label: label, icon: Icons.check, onPressed: () {}),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('button $primary announces its role and disabled state',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await showButton(
        tester,
        primary
            ? const ChambaPrimaryButton(label: 'Guardar', onPressed: null)
            : const ChambaSecondaryButton(label: 'Guardar', onPressed: null),
      );
      expect(tester.getSemantics(find.text('Guardar')),
          matchesSemantics(label: 'Guardar', isButton: true,
              hasEnabledState: true, isEnabled: false));
      semantics.dispose();
    });
  }

  testWidgets('yellow confirmation button has readable text contrast',
      (tester) async {
    await showButton(tester,
        ChambaPrimaryButton(label: 'Aceptar', isYellow: true, onPressed: () {}));
    final foreground = tester.widget<Text>(find.text('Aceptar')).style!.color!;
    final background = AppTheme.colorHighlight;
    final light = background.computeLuminance();
    final dark = foreground.computeLuminance();
    final ratio = (light > dark ? light + .05 : dark + .05) /
        (light > dark ? dark + .05 : light + .05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });
}
