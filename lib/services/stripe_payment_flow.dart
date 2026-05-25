import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../core/config.dart';
import 'api_client.dart';
import 'subscription_service.dart';

/// Pago Premium con Stripe Payment Sheet (UI nativa dentro de la app).
class StripePaymentFlow {
  StripePaymentFlow._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    final key = Config.stripePublishableKey;
    if (key.isEmpty) {
      throw StateError(
        'STRIPE_PUBLISHABLE_KEY no está configurada en .env',
      );
    }
    Stripe.publishableKey = key;
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  /// Muestra el formulario de pago embebido. Devuelve `true` si el pago se completó.
  static Future<bool> presentPremiumSubscriptionPayment(ApiClient api) async {
    await ensureInitialized();

    final paymentService = SubscriptionPaymentService(api);
    final intent = await paymentService.createPaymentIntent();
    if (intent.clientSecret.isEmpty) {
      throw StateError('El servidor no devolvió datos de pago. Intenta de nuevo.');
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        merchantDisplayName: 'Keepi',
        style: ThemeMode.system,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return true;
  }

  /// Mensaje legible para errores de pago o API.
  static String errorMessage(Object error) {
    if (error is StripeException) {
      final code = error.error.code;
      if (code == FailureCode.Canceled) {
        return 'Pago cancelado';
      }
      return error.error.localizedMessage ?? error.error.message ?? 'Error en el pago';
    }
    if (error is DioException) {
      final detail = error.response?.data is Map
          ? (error.response?.data as Map)['detail']
          : null;
      if (detail is String && detail.isNotEmpty) return detail;
      return error.message ?? 'Error de conexión al procesar el pago';
    }
    return error.toString();
  }

  static bool isUserCanceled(Object error) {
    return error is StripeException && error.error.code == FailureCode.Canceled;
  }
}
