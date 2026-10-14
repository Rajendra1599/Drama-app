/// Firebase Web App Configuration with secure --dart-define support
class FirebaseConfig {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: "AIzaSyCfP0Rehsu73-fxZn8Lo2K7V7-DuIpgeDk");
  static const String authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: "storyup-ceaf2.firebaseapp.com");
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: "storyup-ceaf2");
  static const String storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: "storyup-ceaf2.firebasestorage.app");
  static const String messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: "505349965003");
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: "1:505349965003:web:6bff4f7e6f397bd0c1c74e");

  static bool get isConfigured => apiKey.isNotEmpty && projectId.isNotEmpty;

  static Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'authDomain': authDomain,
      'projectId': projectId,
      'storageBucket': storageBucket,
      'messagingSenderId': messagingSenderId,
      'appId': appId,
    };
  }
}
