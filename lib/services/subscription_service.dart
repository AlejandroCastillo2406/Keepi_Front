import '../core/api_endpoints.dart';
import 'api_client.dart';

class SubscriptionService {
  SubscriptionService(this._api);
  final ApiClient _api;

  Future<UsageStatsResponse> getUsageStats() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.subscriptionsUsageStats,
    );
    return UsageStatsResponse.fromJson(res.data!);
  }
}

class UsageStatsResponse {
  UsageStatsResponse({
    required this.analysisUsed,
    required this.analysisLimit,
    required this.analysisRemaining,
    this.plan,
  });

  final int analysisUsed;
  /// -1 significa ilimitado (plan premium).
  final int analysisLimit;
  final int analysisRemaining;
  final String? plan;

  factory UsageStatsResponse.fromJson(Map<String, dynamic> json) {
    final period = json['current_period'] as Map<String, dynamic>? ?? {};
    final status = json['subscription_status'] as Map<String, dynamic>? ?? {};
    return UsageStatsResponse(
      analysisUsed: (period['analysis_used'] as num?)?.toInt() ?? 0,
      analysisLimit: (period['analysis_limit'] as num?)?.toInt() ?? 2,
      analysisRemaining: (period['analysis_remaining'] as num?)?.toInt() ?? 0,
      plan: status['plan'] as String?,
    );
  }

  bool get isUnlimited => analysisLimit < 0;
}

class SubscriptionCheckoutService {
  SubscriptionCheckoutService(this._api);
  final ApiClient _api;

  Future<CheckoutSessionResponse> createCheckoutSession() async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.subscriptionsCreateCheckout,
      data: {'plan': 'premium'},
    );
    return CheckoutSessionResponse.fromJson(res.data!);
  }
}

class CheckoutSessionResponse {
  CheckoutSessionResponse({
    required this.checkoutUrl,
    this.checkoutSessionId,
  });

  final String checkoutUrl;
  final String? checkoutSessionId;

  factory CheckoutSessionResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionResponse(
      checkoutUrl: json['checkout_url'] as String? ?? '',
      checkoutSessionId: json['checkout_session_id'] as String?,
    );
  }
}
