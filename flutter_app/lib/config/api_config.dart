import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class ApiConfig {
  // Live Production Hosted URL
  static const String liveBaseUrl = 'https://updated-story-up.onrender.com';
  // Fast Local USB / Localhost Backend (mapped via adb reverse tcp:5000 tcp:5000)
  static const String localBaseUrl = 'http://127.0.0.1:5000';

  static String _overrideBaseUrl = '';

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    if (kDebugMode || kIsWeb) {
      return localBaseUrl;
    }
    return liveBaseUrl;
  }

  static void useLive() {
    _overrideBaseUrl = liveBaseUrl;
  }

  static void useLocal() {
    _overrideBaseUrl = localBaseUrl;
  }

  // Endpoints
  static String get health => '$baseUrl/api/health';
  static String get googleAuth => '$baseUrl/api/auth/google';
  static String get sendOtp => '$baseUrl/api/auth/send-otp';
  static String get verifyOtp => '$baseUrl/api/auth/verify-otp';
  static String get dramas => '$baseUrl/api/dramas';
  static String get search => '$baseUrl/api/search';
  static String get trending => '$baseUrl/api/feed/trending';
  static String get authorizeEpisode => '$baseUrl/api/episodes/authorize';
  static String get viewEpisode => '$baseUrl/api/episodes/view';
  static String get directUploadSig =>
      '$baseUrl/api/episodes/direct-upload-signature';
  static String get initiatePayment => '$baseUrl/api/payment/initiate';
  static String get verifyPayment => '$baseUrl/api/payment/verify';
  static String get cancelPayment => '$baseUrl/api/payment/cancel';
  static String subscription(String userId) =>
      '$baseUrl/api/subscription/$userId';
  static String get activateTrial =>
      '$baseUrl/api/subscription/activate-1day-trial';
  static String get cancelSubscription => '$baseUrl/api/subscription/cancel';
  static String dramaEpisodes(String seriesId) =>
      '$baseUrl/api/dramas/$seriesId/episodes';
}
