class UserSubscription {
  final String userId;
  final String planId;
  final String planName;
  final String status;
  final int validUntilEpoch;
  final bool isAutoPayEnabled;
  final String paymentProvider;
  final String mandateRef;
  final int activatedAt;

  UserSubscription({
    required this.userId,
    this.planId = 'vip_trial_1day',
    this.planName = '24-Hour VIP Trial Pass',
    this.status = 'ACTIVE',
    required this.validUntilEpoch,
    this.isAutoPayEnabled = true,
    this.paymentProvider = 'PhonePe AutoPay',
    this.mandateRef = '',
    this.activatedAt = 0,
  });

  bool get isVipActive => status == 'ACTIVE' && DateTime.now().millisecondsSinceEpoch < validUntilEpoch;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['userId']?.toString() ?? '',
      planId: json['planId']?.toString() ?? 'vip_trial_1day',
      planName: json['planName']?.toString() ?? '24-Hour VIP Trial Pass',
      status: json['status']?.toString() ?? (json['isVip'] == true ? 'ACTIVE' : 'FREE_ACCOUNT'),
      validUntilEpoch: (json['validUntilEpoch'] as num?)?.toInt() ?? 0,
      isAutoPayEnabled: json['isAutoPayEnabled'] ?? true,
      paymentProvider: json['paymentProvider']?.toString() ?? 'PhonePe AutoPay',
      mandateRef: json['mandateRef']?.toString() ?? '',
      activatedAt: (json['activatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'status': status,
      'validUntilEpoch': validUntilEpoch,
      'isAutoPayEnabled': isAutoPayEnabled,
      'paymentProvider': paymentProvider,
      'mandateRef': mandateRef,
      'activatedAt': activatedAt,
    };
  }
}
