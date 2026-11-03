import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/work_modalities_service.dart';
import 'package:mobile/features/request/presentation/screens/request_modality_screen.dart';

Future<void> _open(WidgetTester tester, WorkModalitiesService service) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: RequestModalityScreen(
      initialPrompt: 'Pintar la sala',
      modalitiesService: service,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(WorkModalitiesService.clearCache);

  testWidgets('solo muestra las modalidades que el admin dejó activas',
      (tester) async {
    await _open(
      tester,
      WorkModalitiesService(
        fetch: () async => {'fixed': true, 'hourly': false, 'daily': true},
      ),
    );
    expect(find.text('Por trabajo'), findsOneWidget);
    expect(find.text('Por día'), findsOneWidget);
    expect(find.text('Por hora'), findsNothing);
  });

  testWidgets('si el backend no responde, muestra todas', (tester) async {
    await _open(
      tester,
      WorkModalitiesService(fetch: () async => throw Exception('sin red')),
    );
    expect(find.text('Por trabajo'), findsOneWidget);
    expect(find.text('Por hora'), findsOneWidget);
    expect(find.text('Por día'), findsOneWidget);
  });

  test('lectura tolerante de la configuración', () {
    final settings = WorkModalitiesSettings.fromJson({'daily': false});
    expect(settings.fixed, isTrue);
    expect(settings.hourly, isTrue);
    expect(settings.isEnabled('daily'), isFalse);
    expect(settings.isEnabled('otra'), isTrue);
  });
}
