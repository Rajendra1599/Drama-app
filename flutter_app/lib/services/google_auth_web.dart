// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class GoogleAuthWebService {
  /// Triggers Google Account Chooser popup via HTML5 Web Messaging
  static Future<Map<String, dynamic>?> triggerGoogleAccountChooser() async {
    final completer = Completer<Map<String, dynamic>?>();

    late StreamSubscription sub;
    sub = html.window.onMessage.listen((event) {
      try {
        final raw = event.data;
        if (raw is String && raw.contains('"storyup_auth":true')) {
          sub.cancel();
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          if (parsed['error'] != null) {
            completer.completeError(parsed['error']);
          } else {
            completer.complete(parsed);
          }
        }
      } catch (_) {}
    });

    html.window.postMessage('TRIGGER_GOOGLE_SIGN_IN', '*');

    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        sub.cancel();
        return null;
      },
    );
  }

  /// Sends Firebase credentials to web runtime
  static void initFirebase(Map<String, dynamic> config) {
    try {
      html.window.postMessage(
        jsonEncode({'action': 'INIT_FIREBASE', 'config': config}),
        '*',
      );
    } catch (_) {}
  }

  /// Signs out web session
  static Future<void> signOut() async {
    try {
      html.window.postMessage('TRIGGER_GOOGLE_SIGN_OUT', '*');
    } catch (_) {}
  }
}
