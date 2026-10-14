class PaymentTransaction {
  final String id;
  final String userId;
  final String planName;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String status;
  final String bankRefId;
  final int createdAt;

  PaymentTransaction({
    required this.id,
    required this.userId,
    this.planName = 'StoryUp VIP Trial Pass',
    this.amount = 1.0,
    this.currency = 'INR',
    this.paymentMethod = 'PhonePe UPI AutoPay',
    this.status = 'SUCCESS',
    this.bankRefId = '',
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? 'StoryUp VIP Trial Pass',
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      currency: json['currency']?.toString() ?? 'INR',
      paymentMethod: json['paymentMethod']?.toString() ?? 'PhonePe UPI AutoPay',
      status: json['status']?.toString() ?? 'SUCCESS',
      bankRefId: json['bankRefId']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planName': planName,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'status': status,
      'bankRefId': bankRefId,
      'createdAt': createdAt,
    };
  }
}
