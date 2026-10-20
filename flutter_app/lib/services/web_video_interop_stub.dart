import 'package:flutter/foundation.dart';

class WebVideoInterop {
  static void setupVideoClickHandlers({VoidCallback? onToggle}) {
    // No-op on Android / iOS / Native platforms
  }

  static void pauseAllWebVideos() {
    // No-op on Android / iOS / Native platforms
  }

  static void optimizeWebVideos() {
    // No-op on native platforms
  }

  static void preloadVideo(String url) {
    // No-op on native platforms
  }
}
