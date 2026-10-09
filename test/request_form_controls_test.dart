import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/request/presentation/widgets/request_form_widgets.dart';

void main() {
  testWidgets(
      'duration controls preserve typed values and cannot decrement below one',
      (tester) async {
    final controller = TextEditingController(text: '1');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RequestQuantityField(
                label: 'Días de trabajo', controller: controller))));
    await tester.tap(find.byTooltip('Reducir Días de trabajo'));
    expect(controller.text, '1');
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.byTooltip('Aumentar Días de trabajo'));
    expect(controller.text, '5');
    await tester.tap(find.byTooltip('Reducir Días de trabajo'));
    expect(controller.text, '4');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
      'rate field preserves decimal input used to calculate the request budget',
      (tester) async {
    final controller = TextEditingController(text: '100');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RequestAmountField(
                label: 'Pago por día', controller: controller))));
    await tester.enterText(find.byType(TextField), '125.50');
    expect(double.parse(controller.text) * 4, 502);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('duration and rate panels fit a narrow device with enlarged text',
      (tester) async {
    final days = TextEditingController(text: '2');
    final rate = TextEditingController(text: '100');
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 270,
                        child: Row(children: [
                          Expanded(
                              child: RequestQuantityField(
                                  label: 'Días de trabajo', controller: days)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: RequestAmountField(
                                  label: 'Pago por día', controller: rate))
                        ])))))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    days.dispose();
    rate.dispose();
  });
}
