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
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {
          'success': false,
          'redirected': true,
          'message': 'Redirected to Razorpay checkout',
        };
      } catch (e) {
        return {
          'success': false,
          'error': 'Could not launch payment URL: $e',
        };
      }
    }
    return {
      'success': false,
      'error': 'No payment URL provided for mobile checkout',
    };
  }
}
