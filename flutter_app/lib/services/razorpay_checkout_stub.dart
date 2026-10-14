import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class RazorpayCheckoutService {
  /// On non-web (mobile/desktop), opens the Razorpay hosted payment link or shortUrl directly
  static Future<Map<String, dynamic>> openCheckout({
    required Map<String, dynamic> options,
    String? shortUrl,
  }) async {
    if (shortUrl != null && shortUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(shortUrl);
        debugPrint('[RazorpayStub] Launching checkout URL: $shortUrl');

        bool launched = false;
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e1) {
          debugPrint('[RazorpayStub] externalApplication launch failed: $e1, trying platformDefault');
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }

        if (!launched) {
          try {
            launched = await launchUrl(uri);
          } catch (_) {}
        }

        return {
          'success': false,
          'redirected': launched,
          'message': launched ? 'Redirected to Razorpay checkout' : 'Could not launch browser',
        };
      } catch (e) {
        debugPrint('[RazorpayStub] Critical launchUrl error: $e');
        return {
          'success': false,
          'error': 'Could not launch payment URL: $e',
        };
      }
    }

    debugPrint('[RazorpayStub] No shortUrl provided for checkout');
    return {
      'success': false,
      'error': 'No payment URL provided for mobile checkout',
    };
  }
}
