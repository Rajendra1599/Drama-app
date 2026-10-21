import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

class ApiConfig {
  // Live Production Hosted URL
  static const String liveBaseUrl = 'https://updated-story-up.onrender.com';
  // Fast Local USB / Localhost Backend (mapped via adb reverse tcp:5000 tcp:5000)
  static const String localBaseUrl = 'http://127.0.0.1:5000';
  // Fast Local Wi-Fi / LAN IP (works directly without USB/adb reverse)
  static const String lanBaseUrl = 'http://192.168.1.33:5000';

  static String _overrideBaseUrl = '';
  // Default to liveBaseUrl for real mobile devices so standalone app on 4G/Wi-Fi works immediately
  static String _activeBaseUrl = liveBaseUrl;
  static bool _hasProbed = false;

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    if (kIsWeb) return localBaseUrl;
    return _activeBaseUrl;
  }

  static Future<void> autoDetectBackend() async {
    if (_hasProbed || kIsWeb) return;
    _hasProbed = true;

    // 1. Probe Localhost via USB ADB reverse (300ms)
    try {
      final res = await http.get(Uri.parse('$localBaseUrl/health/live')).timeout(const Duration(milliseconds: 300));
      if (res.statusCode == 200) {
        _activeBaseUrl = localBaseUrl;
        debugPrint('⚡ [ApiConfig] Localhost USB backend connected (0ms)');
        return;
      }
    } catch (_) {}

    // 2. Probe LAN IP over local Wi-Fi (400ms)
    try {
      final res = await http.get(Uri.parse('$lanBaseUrl/health/live')).timeout(const Duration(milliseconds: 400));
      if (res.statusCode == 200) {
        _activeBaseUrl = lanBaseUrl;
        debugPrint('⚡ [ApiConfig] Local Wi-Fi LAN backend connected ($lanBaseUrl)');
        return;
      }
    } catch (_) {}

    // 3. Fallback to live production hosted backend
    _activeBaseUrl = liveBaseUrl;
    debugPrint('🌐 [ApiConfig] Live production backend active ($liveBaseUrl)');
  }

  static void useLive() {
    _overrideBaseUrl = liveBaseUrl;
  }

  static void useLocal() {
    _overrideBaseUrl = localBaseUrl;
  }

  static void useLan() {
    _overrideBaseUrl = lanBaseUrl;
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
  static String episodePlayback(String episodeId) =>
      '$baseUrl/api/episodes/$episodeId/playback';
}
