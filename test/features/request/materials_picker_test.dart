import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/request/presentation/widgets/request_extras_widgets.dart';

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('el cliente elige entre solo mano de obra o con materiales',
      (tester) async {
    var mode = MaterialsMode.client;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => RequestMaterialsPicker(
        mode: mode,
        onChanged: (next) => setState(() => mode = next),
      ),
    )));

    expect(find.text('Solo mano de obra'), findsOneWidget);
    expect(find.text('Mano de obra + materiales'), findsOneWidget);

    await tester.tap(find.text('Mano de obra + materiales'));
    await tester.pumpAndSettle();
    expect(mode, MaterialsMode.worker);
    // El cliente no sabe qué materiales hacen falta: no se le pide detalle.
    expect(find.byType(TextField), findsNothing);
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

  group('precio de la oferta que ve el cliente', () {
    testWidgets('con materiales: mano de obra grande y materiales aparte',
        (tester) async {
      // Pedro ofrece 300 de mano de obra y 700 de materiales: amount = 1000.
      await tester
          .pumpWidget(host(const OfferPrice(amount: 1000, materials: 700)));
      expect(find.text('Bs 300'), findsOneWidget);
      expect(find.text('mano de obra'), findsOneWidget);
      expect(find.text('+ Bs 700 materiales'), findsOneWidget);
      expect(find.text('Bs 1000'), findsNothing);
    });

    testWidgets('solo mano de obra: un solo precio', (tester) async {
      await tester.pumpWidget(host(const OfferPrice(amount: 300)));
      expect(find.text('Bs 300'), findsOneWidget);
      expect(find.textContaining('materiales'), findsNothing);
      expect(find.text('mano de obra'), findsNothing);
    });

    testWidgets('por hora con materiales: tarifa de la mano de obra',
        (tester) async {
      await tester.pumpWidget(
          host(const OfferPrice(amount: 1000, materials: 700, hours: 3)));
      expect(find.text('Bs 100/h'), findsOneWidget);
      expect(find.text('mano de obra, Bs 300'), findsOneWidget);
      expect(find.text('+ Bs 700 materiales'), findsOneWidget);
    });
  });

  group('monto en el seguimiento', () {
    testWidgets('solo mano de obra: igual que antes, sin ".0" ni "1 días"',
        (tester) async {
      await tester.pumpWidget(host(const JobAmountSummary(
          amount: 180, modality: 'daily', days: 1)));
      expect(find.text('Bs 180'), findsOneWidget);
      expect(find.text('Por día · 1 día × Bs 180'), findsOneWidget);
      expect(find.byType(MaterialsPill), findsNothing);
      expect(find.textContaining('Total'), findsNothing);
    });

    testWidgets('precio fijo sin materiales', (tester) async {
      await tester.pumpWidget(host(const JobAmountSummary(amount: 250)));
      expect(find.text('Bs 250'), findsOneWidget);
      expect(find.text('Precio fijo'), findsOneWidget);
    });

    testWidgets('con materiales: mano de obra, materiales y total',
        (tester) async {
      await tester.pumpWidget(
          host(const JobAmountSummary(amount: 1000, materials: 700)));
      expect(find.text('Bs 300'), findsOneWidget);
      expect(find.text('mano de obra'), findsOneWidget);
      expect(find.text('+ Bs 700 materiales'), findsOneWidget);
      expect(find.text('Total Bs 1000'), findsOneWidget);
    });

    testWidgets('por día con materiales: la tarifa es de la mano de obra',
        (tester) async {
      await tester.pumpWidget(host(const JobAmountSummary(
          amount: 1000, materials: 700, modality: 'daily', days: 2)));
      expect(find.text('Bs 300'), findsOneWidget);
      expect(find.text('mano de obra · Por día · 2 días × Bs 150'),
          findsOneWidget);
    });
  });
}
