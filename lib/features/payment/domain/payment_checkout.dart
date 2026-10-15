import '../../../core/services/mobile_backend_service.dart';

/// Qué debe dibujar la app para cobrar. Lo decide el backend según el
/// proveedor configurado en el admin; la app no sabe qué banco hay detrás.
enum PaymentAction { none, qr, cardSheet, openUrl, unknown }

enum PaymentStatus {
  notRequired,
  pending,
  reported,
  paid,
  failed,
  expired,
  cancelled,
  unknown,
}

PaymentAction _action(Object? raw) => switch (raw?.toString()) {
      'none' => PaymentAction.none,
      'qr' => PaymentAction.qr,
      'card_sheet' => PaymentAction.cardSheet,
      'open_url' => PaymentAction.openUrl,
      // Una acción nueva que esta versión no conoce: se pide actualizar.
      _ => PaymentAction.unknown,
    };

PaymentStatus _status(Object? raw) => switch (raw?.toString()) {
      'not_required' => PaymentStatus.notRequired,
      'pending' => PaymentStatus.pending,
      'reported' => PaymentStatus.reported,
      'paid' => PaymentStatus.paid,
      'failed' => PaymentStatus.failed,
      'expired' => PaymentStatus.expired,
      'cancelled' => PaymentStatus.cancelled,
      _ => PaymentStatus.unknown,
    };

String? _text(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

/// Respuesta de `POST /mobile/payments/checkout` y `GET /mobile/payments/:id`.
/// Lectura tolerante: campos que falten o sobren no rompen la app.
class PaymentCheckout {
  const PaymentCheckout({
    required this.id,
    required this.status,
    required this.action,
    required this.amount,
    required this.currency,
    this.title = 'Pago',
    this.methodName = '',
    this.instructions,
    this.qrImageUrl,
    this.qrImageBase64,
    this.cardClientSecret,
    this.cardEphemeralKey,
    this.cardCustomer,
    this.cardPublishableKey,
    this.url,
    this.expiresAt,
    this.canReportPaid = false,
    this.pollSeconds = 0,
  });

  factory PaymentCheckout.fromJson(Map<String, dynamic> json) {
    final qr = json['qr'] is Map ? Map<String, dynamic>.from(json['qr']) : null;
    final card =
        json['card'] is Map ? Map<String, dynamic>.from(json['card']) : null;
    return PaymentCheckout(
      id: _text(json['id']),
      status: _status(json['status']),
      action: _action(json['action']),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: _text(json['currency']) ?? 'BOB',
      title: _text(json['title']) ?? 'Pago',
      methodName: _text(json['methodName']) ?? '',
      instructions: _text(json['instructions']),
      qrImageUrl: _text(qr?['imageUrl']),
      qrImageBase64: _text(qr?['imageBase64']),
      cardClientSecret: _text(card?['clientSecret']),
      cardEphemeralKey: _text(card?['ephemeralKey']),
      cardCustomer: _text(card?['customer']),
      cardPublishableKey: _text(card?['publishableKey']),
      url: _text(json['url']),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '')?.toLocal(),
      canReportPaid: json['canReportPaid'] == true,
      pollSeconds: int.tryParse(json['pollSeconds']?.toString() ?? '') ?? 0,
    );
  }

  final String? id;
  final PaymentStatus status;
  final PaymentAction action;
  final double amount;
  final String currency;
  final String title;
  final String methodName;
  final String? instructions;
  final String? qrImageUrl;
  final String? qrImageBase64;
  final String? cardClientSecret;
  final String? cardEphemeralKey;
  final String? cardCustomer;
  final String? cardPublishableKey;
  final String? url;
  final DateTime? expiresAt;
  final bool canReportPaid;
  final int pollSeconds;

  /// Con estos estados ya se puede aceptar la oferta.
  bool get isSettled =>
      status == PaymentStatus.notRequired ||
      status == PaymentStatus.paid ||
      status == PaymentStatus.reported;

  /// El cobro terminó sin pago: hay que generar otro o elegir otra cosa.
  bool get isDead =>
      status == PaymentStatus.failed ||
      status == PaymentStatus.expired ||
      status == PaymentStatus.cancelled;

  /// "Bs 150" / "USD 12.50".
  String get amountLabel {
    final symbol =
        currency.toUpperCase() == 'BOB' ? 'Bs' : currency.toUpperCase();
    final fixed = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$symbol $fixed';
  }
}

/// Acceso al backend; se reemplaza en pruebas.
class PaymentApi {
  const PaymentApi();

  Future<PaymentCheckout> checkout(String offerId) async =>
      PaymentCheckout.fromJson(await MobileBackendService.instance
          .paymentCheckout(offerId: offerId));

  Future<PaymentCheckout> status(String paymentId) async =>
      PaymentCheckout.fromJson(
          await MobileBackendService.instance.paymentStatus(paymentId));

  Future<PaymentCheckout> reportPaid(String paymentId) async =>
      PaymentCheckout.fromJson(
          await MobileBackendService.instance.reportPaymentPaid(paymentId));
}
