import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthWebService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '505349965003-9ungrjvf5qulmj6h0r1hrk2iij5aucmp.apps.googleusercontent.com',
    scopes: <String>['email'],
  );

  /// Signs out and disconnects Google account completely
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('[GoogleSignIn] signOut error: $e');
    }
  }

  /// Triggers native Android/iOS Google Account Chooser
  /// Displays all Google accounts logged in on the device
  static Future<Map<String, dynamic>?> triggerGoogleAccountChooser() async {
    try {
      // Disconnect previous session so Android always shows the account chooser list
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signIn();
      } catch (e) {
        debugPrint('[GoogleSignIn] Standard signIn failed: $e');
        // Fallback: Attempt sign in silently if available, or retry
        try {
          account = await _googleSignIn.signInSilently();
        } catch (e2) {
          debugPrint('[GoogleSignIn] Fallback signIn failed: $e2');
          return {'error': e.toString()};
        }
        if (account == null) {
          return {'error': e.toString()};
        }
      }

      if (account == null) {
        // User cancelled or closed the account chooser
        return null;
      }

      String? idToken;
      try {
        final auth = await account.authentication;
        idToken = auth.idToken;
      } catch (e) {
        debugPrint('[GoogleSignIn] Token error: $e');
      }

      return {
        'email': account.email,
        'displayName': account.displayName ?? account.email.split('@')[0],
        'photoUrl': account.photoUrl,
        'idToken': idToken,
        'id': account.id,
      };
    } catch (e) {
      debugPrint('[GoogleSignIn] Native Play Services error: $e');
      return {'error': e.toString()};
    }
  }

  static void initFirebase(Map<String, dynamic> config) {}
}
