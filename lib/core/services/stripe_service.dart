import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';

class StripeService {
  static final StripeService instance = StripeService._();
  StripeService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init(String publishableKey) async {
    if (publishableKey.isEmpty) return;
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    _isInitialized = true;
  }

  Future<bool> presentPaymentSheet({
    required String clientSecret,
    String? ephemeralKey,
    String? customerId,
  }) async {
    try {
      // 1. Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: customerId,
          merchantDisplayName: 'Chamba',
          allowsDelayedPaymentMethods: true,
          style: ThemeMode.light,
        ),
      );

      // 2. Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      // If we reach here, payment was completed successfully
      return true;
    } on StripeException catch (e) {
      debugPrint('Stripe Error: ${e.error.localizedMessage}');
      return false;
    } catch (e) {
      debugPrint('Stripe Error: $e');
      return false;
    }
  }
}
