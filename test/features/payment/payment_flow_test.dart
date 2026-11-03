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
      // Versiones viejas del backend podían mandarlo en true: ya no existe
      // "Ya pagué" y la app lo ignora.
      'canReportPaid': true,
      'pollSeconds': pollSeconds,
      // Campo que esta versión no conoce: debe ignorarse sin romper.
      'algoNuevo': {'x': 1},
    };

class _FakeApi extends PaymentApi {
  _FakeApi(this.first, {this.onStatus});

  final Map<String, dynamic> first;
  final Map<String, dynamic> Function()? onStatus;
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

  testWidgets('QR: muestra monto, QR e instrucciones, sin botón "Ya pagué"',
      (tester) async {
    final api = _FakeApi(_json());
    final outcomes = await _launch(tester, api);
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);
    expect(find.text('Bs 150'), findsOneWidget);
    expect(find.text('Escanea con tu banco'), findsOneWidget);
    expect(find.text('Guardar o compartir QR'), findsOneWidget);
    // Aunque un backend viejo mande canReportPaid, ya no existe "Ya pagué":
    // el pago solo pasa cuando el banco lo confirma por su API.
    expect(find.text('Ya pagué'), findsNothing);
    expect(outcomes, isEmpty);
    await tester.tap(find.text('Pagar después'));
    await _settle(tester);
  });

  test('un pago "reportado" (viejo) no habilita aceptar la oferta', () {
    final legacy = PaymentCheckout.fromJson(_json(status: 'reported'));
    expect(legacy.status, PaymentStatus.reported);
    expect(legacy.isSettled, isFalse);
    expect(PaymentCheckout.fromJson(_json(status: 'paid')).isSettled, isTrue);
    // Estados de reembolso: la app no los conoce y no los toma como pagados.
    final refund = PaymentCheckout.fromJson(_json(status: 'refund_pending'));
    expect(refund.status, PaymentStatus.unknown);
    expect(refund.isSettled, isFalse);
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
      _json(pollSeconds: 3),
      onStatus: () =>
          _json(status: confirmed ? 'paid' : 'pending', pollSeconds: 3),
    );
    final outcomes = await _launch(tester, api);

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
    await tester.tap(find.byKey(const Key('payment-retry')));
    await _settle(tester);
    expect(api.checkouts, 2);
    await tester.tap(find.text('Pagar después'));
    await _settle(tester);
  });

  testWidgets('pasarela con enlace: muestra el botón para abrirla',
      (tester) async {
    await _launch(
        tester, _FakeApi(_json(action: 'open_url')));
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
        ..._json(action: 'card_sheet'),
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
