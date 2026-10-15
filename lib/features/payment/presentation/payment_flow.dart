import 'package:flutter/material.dart';

import '../../../core/services/stripe_service.dart';
import '../domain/payment_checkout.dart';
import 'payment_screen.dart';

enum PaymentOutcome {
  /// El método no cobra en la app (efectivo, etc.).
  notRequired,

  /// Pagado o reportado: ya se puede aceptar la oferta.
  paid,

  /// El cliente salió sin pagar.
  cancelled,
}

/// Paga con tarjeta (Stripe Payment Sheet). Se puede reemplazar en pruebas.
typedef CardSheetPresenter = Future<bool> Function(PaymentCheckout payment);

Future<bool> _presentStripeSheet(PaymentCheckout payment) async {
  final stripe = StripeService.instance;
  if (!stripe.isInitialized && payment.cardPublishableKey != null) {
    await stripe.init(payment.cardPublishableKey!);
  }
  if (!stripe.isInitialized || payment.cardClientSecret == null) {
    throw Exception(
        'Los pagos con tarjeta no están disponibles en este momento.');
  }
  return stripe.presentPaymentSheet(
    clientSecret: payment.cardClientSecret!,
    ephemeralKey: payment.cardEphemeralKey,
    customerId: payment.cardCustomer,
  );
}

/// Cobra una oferta antes de aceptarla. La app no decide nada: pide el cobro
/// al backend y dibuja la acción que llega (nada, QR, tarjeta o enlace).
class PaymentFlow {
  const PaymentFlow._();

  static Future<PaymentOutcome> forOffer(
    BuildContext context, {
    required String offerId,
    PaymentApi api = const PaymentApi(),
    CardSheetPresenter presentCard = _presentStripeSheet,
  }) async {
    final payment = await api.checkout(offerId);
    if (payment.status == PaymentStatus.notRequired ||
        payment.action == PaymentAction.none) {
      return PaymentOutcome.notRequired;
    }
    if (payment.isSettled) return PaymentOutcome.paid;
    if (!context.mounted) return PaymentOutcome.cancelled;

    switch (payment.action) {
      case PaymentAction.cardSheet:
        return await presentCard(payment)
            ? PaymentOutcome.paid
            : PaymentOutcome.cancelled;
      case PaymentAction.qr:
      case PaymentAction.openUrl:
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                PaymentScreen(offerId: offerId, initial: payment, api: api),
          ),
        );
        return paid == true ? PaymentOutcome.paid : PaymentOutcome.cancelled;
      case PaymentAction.none:
        return PaymentOutcome.notRequired;
      case PaymentAction.unknown:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Actualiza Chamba'),
            content: const Text(
              'Este método de pago necesita la última versión de la app. '
              'Actualízala desde la tienda o elige otro método de pago.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return PaymentOutcome.cancelled;
    }
  }
}
