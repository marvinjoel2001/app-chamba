import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/payment/domain/payment_checkout.dart';
import 'package:mobile/features/payment/presentation/payment_flow.dart';

// PNG transparente de 1x1 para no depender de la red en las pruebas.
const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Map<String, dynamic> _json({
  String status = 'pending',
  String action = 'qr',
  bool canReportPaid = true,
  int pollSeconds = 0,
  String? expiresAt,
}) =>
    {
      'id': 'p1',
      'status': status,
      'action': action,
      'amount': 150,
      'currency': 'BOB',
      'title': 'Pago de "Pintar sala"',
      'methodName': 'QR',
      'instructions': 'Escanea con tu banco',
      'qr': {'imageUrl': null, 'imageBase64': _pixel},
      'card': null,
      'url': action == 'open_url' ? 'https://pagos.ejemplo/123' : null,
      'expiresAt': expiresAt,
      'canReportPaid': canReportPaid,
      'pollSeconds': pollSeconds,
      // Campo que esta versión no conoce: debe ignorarse sin romper.
      'algoNuevo': {'x': 1},
    };

class _FakeApi extends PaymentApi {
  _FakeApi(this.first, {this.onStatus});

  final Map<String, dynamic> first;
  final Map<String, dynamic> Function()? onStatus;
  int reports = 0;
  int checkouts = 0;
  int statuses = 0;

  @override
  Future<PaymentCheckout> checkout(String offerId) async {
    checkouts++;
    return PaymentCheckout.fromJson(first);
  }

  @override
  Future<PaymentCheckout> status(String paymentId) async {
    statuses++;
    return PaymentCheckout.fromJson(onStatus?.call() ?? first);
  }

  @override
  Future<PaymentCheckout> reportPaid(String paymentId) async {
    reports++;
    return PaymentCheckout.fromJson(
        _json(status: 'reported', canReportPaid: false));
  }
}

/// La pantalla de pago tiene un indicador de espera infinito, así que no se
/// usa pumpAndSettle: se avanzan los cuadros de las transiciones a mano.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Monta un botón que lanza el flujo y guarda el resultado.
Future<List<PaymentOutcome>> _launch(
  WidgetTester tester,
  PaymentApi api, {
  CardSheetPresenter? card,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final outcomes = <PaymentOutcome>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => outcomes.add(await PaymentFlow.forOffer(
            context,
            offerId: 'o1',
            api: api,
            presentCard: card ?? (_) async => true,
          )),
          child: const Text('Aceptar oferta'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Aceptar oferta'));
  await _settle(tester);
  return outcomes;
}

void main() {
  group('lectura del contrato', () {
    test('acepta estados y acciones conocidos y tolera los nuevos', () {
      final p = PaymentCheckout.fromJson(_json());
      expect(p.action, PaymentAction.qr);
      expect(p.status, PaymentStatus.pending);
      expect(p.amountLabel, 'Bs 150');
      expect(p.qrImageBase64, _pixel);

      final future = PaymentCheckout.fromJson(
          {..._json(), 'action': 'nfc_tap', 'status': 'en_revision'});
      expect(future.action, PaymentAction.unknown);
      expect(future.status, PaymentStatus.unknown);
      expect(future.isSettled, isFalse);
    });

    test('montos con decimales y otras monedas', () {
      final p = PaymentCheckout.fromJson(
          {..._json(), 'amount': '12.5', 'currency': 'usd'});
      expect(p.amountLabel, 'USD 12.50');
    });
  });

  testWidgets('efectivo: sigue directo sin mostrar nada', (tester) async {
    final api = _FakeApi(_json(status: 'not_required', action: 'none'));
    final outcomes = await _launch(tester, api);
    expect(outcomes, [PaymentOutcome.notRequired]);
    expect(find.text('Pagar'), findsNothing);
  });

  testWidgets('QR: muestra monto, QR e instrucciones; "Ya pagué" confirma',
      (tester) async {
    final api = _FakeApi(_json());
    final outcomes = await _launch(tester, api);
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);
    expect(find.text('Bs 150'), findsOneWidget);
    expect(find.text('Escanea con tu banco'), findsOneWidget);
    expect(find.text('Guardar o compartir QR'), findsOneWidget);
    expect(outcomes, isEmpty);

    await tester.tap(find.byKey(const Key('payment-report')));
    await _settle(tester);
    // Echarse atrás en la confirmación no reporta nada.
    await tester.tap(find.text('Todavía no'));
    await _settle(tester);
    expect(api.reports, 0);

    await tester.tap(find.byKey(const Key('payment-report')));
    await _settle(tester);
    await tester.tap(find.text('Sí, ya pagué'));
    await _settle(tester);
    expect(api.reports, 1);
    expect(outcomes, [PaymentOutcome.paid]);
  });

  testWidgets('QR: "Pagar después" no acepta la oferta', (tester) async {
    final outcomes = await _launch(tester, _FakeApi(_json()));
    await tester.tap(find.text('Pagar después'));
    await _settle(tester);
    expect(outcomes, [PaymentOutcome.cancelled]);
  });

  testWidgets('se cierra solo cuando el backend confirma el pago',
      (tester) async {
    var confirmed = false;
    final api = _FakeApi(
      _json(pollSeconds: 3, canReportPaid: false),
      onStatus: () =>
          _json(status: confirmed ? 'paid' : 'pending', pollSeconds: 3),
    );
    final outcomes = await _launch(tester, api);
    expect(find.byKey(const Key('payment-report')), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(outcomes, isEmpty);

    confirmed = true;
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(outcomes, [PaymentOutcome.paid]);
  });

  testWidgets('cobro vencido: ofrece generar uno nuevo', (tester) async {
    final api = _FakeApi(_json(
        expiresAt: DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toUtc()
            .toIso8601String()));
    await _launch(tester, api);
    expect(find.text('Este cobro venció.'), findsOneWidget);
    expect(find.byKey(const Key('payment-report')), findsNothing);
    await tester.tap(find.byKey(const Key('payment-retry')));
    await _settle(tester);
    expect(api.checkouts, 2);
    await tester.tap(find.text('Pagar después'));
    await _settle(tester);
  });

  testWidgets('pasarela con enlace: muestra el botón para abrirla',
      (tester) async {
    await _launch(
        tester, _FakeApi(_json(action: 'open_url', canReportPaid: false)));
    expect(find.byKey(const Key('payment-open-url')), findsOneWidget);
    expect(find.byKey(const Key('payment-qr')), findsNothing);
    await tester.tap(find.text('Pagar después'));
    await _settle(tester);
  });

  testWidgets('tarjeta: usa el Payment Sheet con los datos del backend',
      (tester) async {
    PaymentCheckout? shown;
    final outcomes = await _launch(
      tester,
      _FakeApi({
        ..._json(action: 'card_sheet', canReportPaid: false),
        'card': {'clientSecret': 'pi_1_secret', 'publishableKey': 'pk'},
      }),
      card: (p) async {
        shown = p;
        return false; // el cliente cerró el formulario
      },
    );
    expect(shown?.cardClientSecret, 'pi_1_secret');
    expect(outcomes, [PaymentOutcome.cancelled]);
  });

  testWidgets('acción desconocida: pide actualizar la app', (tester) async {
    final outcomes =
        await _launch(tester, _FakeApi({..._json(), 'action': 'nfc_tap'}));
    expect(find.text('Actualiza Chamba'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await _settle(tester);
    expect(outcomes, [PaymentOutcome.cancelled]);
  });
}
