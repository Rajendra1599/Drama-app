// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:url_launcher/url_launcher.dart';

class RazorpayCheckoutService {
  /// On web, triggers Razorpay modal popup via HTML5 window messaging
  static Future<Map<String, dynamic>> openCheckout({
    required Map<String, dynamic> options,
    String? shortUrl,
  }) async {
    final completer = Completer<Map<String, dynamic>>();

    late StreamSubscription sub;
    sub = html.window.onMessage.listen((event) {
      try {
        final raw = event.data;
        if (raw is String && raw.contains('"storyup_razorpay":true')) {
          sub.cancel();
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          final res = parsed['result'] as Map<String, dynamic>? ?? {};
          if (!completer.isCompleted) {
            completer.complete(res);
          }
        }
      } catch (_) {}
    });

    html.window.postMessage(
      jsonEncode({'action': 'OPEN_RAZORPAY', 'options': options}),
      '*',
    );

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        sub.cancel();
        if (shortUrl != null && shortUrl.isNotEmpty) {
          launchUrl(Uri.parse(shortUrl), mode: LaunchMode.externalApplication);
          return {
            'success': false,
            'redirected': true,
            'message': 'Redirected to payment page',
          };
        }
        return {
          'success': false,
          'cancelled': true,
          'message': 'Payment timed out or cancelled',
        };
      },
    );
  }
}
