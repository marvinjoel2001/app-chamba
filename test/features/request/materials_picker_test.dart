import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/request/presentation/widgets/request_extras_widgets.dart';

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('el cliente elige entre solo mano de obra o con materiales',
      (tester) async {
    var mode = MaterialsMode.client;
    final note = TextEditingController();
    addTearDown(note.dispose);
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => RequestMaterialsPicker(
        mode: mode,
        noteController: note,
        onChanged: (next) => setState(() => mode = next),
      ),
    )));

    expect(find.text('Solo mano de obra'), findsOneWidget);
    expect(find.text('Mano de obra + materiales'), findsOneWidget);
    // Solo mano de obra no pide detalle de materiales.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Mano de obra + materiales'));
    await tester.pumpAndSettle();
    expect(mode, MaterialsMode.worker);
    expect(find.byType(TextField), findsOneWidget);
  });

  test('el trabajador ve el mismo nombre que eligió el cliente', () {
    String label(String code) =>
        (requestTagChips({'materialsMode': code}).single as RequestTagChip)
            .label;
    expect(label('client'), 'Solo mano de obra');
    expect(label('worker'), 'Mano de obra + materiales');
    // Solicitudes viejas con "lo hablamos en el chat" no muestran chip.
    expect(requestTagChips({'materialsMode': 'discuss'}), isEmpty);
  });
}
