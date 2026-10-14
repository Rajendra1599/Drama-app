import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_subscription.dart';
import 'api_service.dart';
import 'razorpay_checkout_service.dart';

enum UpiAppTarget {
  autoDetect('Auto-Redirect', '', 'Razorpay AutoPay (PhonePe / GPay / Paytm / Cards)'),
  phonePe('PhonePe', 'com.phonepe.app', 'PhonePe UPI & AutoPay'),
  gpay('Google Pay', 'com.google.android.apps.nbu.paisa.user', 'Google Pay UPI'),
  paytm('Paytm', 'net.one97.paytm', 'Paytm UPI & Wallet'),
  bhim('BHIM', 'in.org.npci.upiapp', 'BHIM UPI');

  final String displayName;
  final String packageName;
  final String shortDesc;
  const UpiAppTarget(this.displayName, this.packageName, this.shortDesc);
}

class SubscriptionPlan {
  final String id;
  final String name;
  final double initialPriceInr;
  final double recurringPriceInr;
  final double originalPriceInr;
  final int discountPercent;
  final String billingCycle;
  final String description;
  final List<String> perks;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.initialPriceInr,
    required this.recurringPriceInr,
    required this.originalPriceInr,
    required this.discountPercent,
    required this.billingCycle,
    required this.description,
    required this.perks,
  });
}

class PaymentService {
  static const trialPlan = SubscriptionPlan(
    id: 'plan_24h_trial',
    name: '24-Hour VIP Trial Pass',
    initialPriceInr: 1.0,
    recurringPriceInr: 599.0,
    originalPriceInr: 599.0,
    discountPercent: 99,
    billingCycle: 'per month',
    description: '24-Hour Trial for ₹1, then ₹599/month AutoPay Mandate',
    perks: [
      '24-Hour Full VIP Access',
      '₹1 AutoPay Setup Fee',
      '₹599/month Mandate After 24h',
      'All Episodes Unlocked',
      'Full HD 1080p Streaming',
      'Zero Ads',
      'Cancel Anytime in Profile',
    ],
  );

  /// Launches Razorpay AutoPay subscription on Web & Mobile
  static Future<Map<String, dynamic>> launchUpiAutoPay({
    required String userId,
    required SubscriptionPlan plan,
    UpiAppTarget target = UpiAppTarget.autoDetect,
  }) async {
    // Step 1: Initiate payment on backend to create Razorpay Subscription / Order
    final initRes = await ApiService.initiatePayment(
      userId: userId,
      planId: plan.id,
      amount: plan.initialPriceInr,
    );

    final txnId = initRes['transactionId'] ??
        'MD_${DateTime.now().millisecondsSinceEpoch}';
    final keyId = initRes['keyId']?.toString() ?? '';
    final subscriptionId = initRes['subscriptionId']?.toString();
    final orderId = initRes['orderId']?.toString();
    final shortUrl = initRes['shortUrl']?.toString();
    final provider = initRes['provider']?.toString() ?? 'razorpay';
    final rawUpiUri = initRes['upiUri']?.toString();

    // Step 2: Handle Simulation Mode (when Razorpay keys are not yet pasted into .env)
    if (provider == 'razorpay_mock') {
      debugPrint('[Payment] Running in simulation mode (keys not yet set in .env)');
      return {
        'transactionId': txnId,
        'amount': plan.initialPriceInr,
        'status': 'PENDING',
        'planName': plan.name,
        'isMock': true,
      };
    }

    // Step 3: Trigger Razorpay Checkout (Web popup modal or redirect)
    final options = <String, dynamic>{
      'key': keyId,
      'amount': (plan.initialPriceInr * 100).toInt(),
      'name': 'StoryUp OTT',
      'description': '1-Day Trial for ₹1, then ₹599/month AutoPay',
      'currency': 'INR',
      'prefill': {
        'name': 'VIP Member',
        'email': 'subscriber@storyup.tv',
        'contact': '9876543210',
      },
      'theme': {
        'color': '#FF2E74',
      },
    };

    if (subscriptionId != null && subscriptionId.isNotEmpty && !subscriptionId.startsWith('sub_test_')) {
      options['subscription_id'] = subscriptionId;
    } else if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    final checkoutRes = await RazorpayCheckoutService.openCheckout(
      options: options,
      shortUrl: shortUrl,
    );

    // If Razorpay checkout modal was completed directly by user
    if (checkoutRes['success'] == true) {
      final sub = await completeVerification(
        transactionId: txnId,
        userId: userId,
        razorpayPaymentId: checkoutRes['razorpay_payment_id']?.toString(),
        razorpaySubscriptionId: checkoutRes['razorpay_subscription_id']?.toString() ?? subscriptionId,
        razorpayOrderId: checkoutRes['razorpay_order_id']?.toString() ?? orderId,
        razorpaySignature: checkoutRes['razorpay_signature']?.toString(),
      );

      return {
        'transactionId': txnId,
        'amount': plan.initialPriceInr,
        'status': 'SUCCESS',
        'planName': plan.name,
        'verified': sub != null,
        'subscription': sub,
      };
    }

    // Fallback: If device has raw UPI URI and couldn't open checkout
    if (checkoutRes['redirected'] != true && rawUpiUri != null && !kIsWeb) {
      try {
        final uri = Uri.parse(rawUpiUri);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    return {
      'transactionId': txnId,
      'amount': plan.initialPriceInr,
      'status': 'PENDING',
      'planName': plan.name,
      'shortUrl': shortUrl,
    };
  }

  /// Verifies payment and activates VIP status
  static Future<UserSubscription?> completeVerification({
    required String transactionId,
    required String userId,
    String? bankRefId,
    String? razorpayPaymentId,
    String? razorpaySubscriptionId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    final verifyRes = await ApiService.verifyPayment(
      transactionId: transactionId,
      userId: userId,
      bankRefId: bankRefId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySubscriptionId: razorpaySubscriptionId,
      razorpayOrderId: razorpayOrderId,
      razorpaySignature: razorpaySignature,
    );

    if (verifyRes['success'] != true || verifyRes['subscription'] == null) {
      return null;
    }

    final subData = verifyRes['subscription'] as Map<String, dynamic>;
    return UserSubscription(
      userId: userId,
      planId: subData['planId']?.toString() ?? 'plan_24h_trial',
      planName: subData['planName']?.toString() ?? '24-Hour VIP Trial Pass',
      status: subData['status']?.toString() ?? 'ACTIVE',
      validUntilEpoch: subData['validUntilEpoch'] is int
          ? subData['validUntilEpoch'] as int
          : (DateTime.now().millisecondsSinceEpoch +
              (30 * 24 * 60 * 60 * 1000)),
      isAutoPayEnabled: true,
      paymentProvider: 'Razorpay AutoPay',
      activatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
