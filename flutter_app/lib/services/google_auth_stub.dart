import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthWebService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '663742323718-7c68ineulji7v2nb8b4pu85aivfooj20.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
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
        // Fallback: If serverClientId triggered ApiException on Play Services, try without serverClientId
        try {
          final fallbackSignIn = GoogleSignIn(
            scopes: <String>[
              'email',
              'https://www.googleapis.com/auth/userinfo.profile',
            ],
          );
          try {
            await fallbackSignIn.signOut();
          } catch (_) {}
          account = await fallbackSignIn.signIn();
        } catch (e2) {
          debugPrint('[GoogleSignIn] Fallback signIn failed: $e2');
          return {'error': e2.toString()};
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
