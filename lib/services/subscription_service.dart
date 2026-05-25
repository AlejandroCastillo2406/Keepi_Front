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

class SubscriptionPaymentService {
  SubscriptionPaymentService(this._api);
  final ApiClient _api;

  Future<PaymentIntentResponse> createPaymentIntent({String plan = 'premium'}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.subscriptionsCreatePaymentIntent,
      data: {'plan': plan},
    );
    return PaymentIntentResponse.fromJson(res.data!);
  }
}

class PaymentIntentResponse {
  PaymentIntentResponse({
    required this.clientSecret,
    required this.status,
    this.subscriptionId,
  });

  final String clientSecret;
  final String status;
  final String? subscriptionId;

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResponse(
      clientSecret: json['client_secret'] as String? ?? '',
      status: json['status'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String?,
    );
  }
}
