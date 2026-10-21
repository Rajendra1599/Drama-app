import 'package:flutter/foundation.dart';

/// Centralized Feature Flags and QoE Performance Telemetry Configuration
/// for MicroDrama / StoryUp Video Streaming.
class StreamingConfig {
  // Feature Flags with instantaneous rollback capability
  static bool enableQoELogs = kDebugMode;
  static bool enableDeferredPrefetch = true;
  static double prefetchThresholdPercent = 0.10;
  static int prefetchRemainingSeconds = 85;
  static bool enablePersistentHttpClient = true;
  static bool enableDiskImageCaching = true;
  static bool enableFastStartMoov = true;

  // Track QoS timing metrics per episode playback
  static final Map<String, PlaybackQoEMetrics> _activeMetrics = {};

  static PlaybackQoEMetrics getMetrics(String episodeId) {
    return _activeMetrics.putIfAbsent(episodeId, () => PlaybackQoEMetrics(episodeId));
  }

  static void clearMetrics(String episodeId) {
    _activeMetrics.remove(episodeId);
  }
}

class PlaybackQoEMetrics {
  final String episodeId;
  final int requestTimeMs;
  int? authResolvedTimeMs;
  int? manifestLoadedTimeMs;
  int? firstFrameRenderedTimeMs;
  int? lastSeekStartTimeMs;

  int rebufferEventCount = 0;
  int totalRebufferDurationMs = 0;
  int? currentRebufferStartTimeMs;
  int totalPlaybackMs = 0;

  PlaybackQoEMetrics(this.episodeId)
      : requestTimeMs = DateTime.now().millisecondsSinceEpoch {
    if (StreamingConfig.enableQoELogs) {
      debugPrint('[QoE TIMING] episode=$episodeId event=playback_request_start t=0ms');
    }
  }

  void markAuthResolved() {
    authResolvedTimeMs = DateTime.now().millisecondsSinceEpoch;
    if (StreamingConfig.enableQoELogs) {
      final elapsed = authResolvedTimeMs! - requestTimeMs;
      debugPrint('[QoE TIMING] episode=$episodeId event=auth_resolved elapsed=${elapsed}ms');
    }
  }

  void markManifestLoaded() {
    manifestLoadedTimeMs = DateTime.now().millisecondsSinceEpoch;
    if (StreamingConfig.enableQoELogs) {
      final elapsed = manifestLoadedTimeMs! - requestTimeMs;
      debugPrint('[QoE TIMING] episode=$episodeId event=manifest_loaded elapsed=${elapsed}ms');
    }
  }

  void markFirstFrameRendered() {
    if (firstFrameRenderedTimeMs != null) return;
    firstFrameRenderedTimeMs = DateTime.now().millisecondsSinceEpoch;
    final ttffMs = firstFrameRenderedTimeMs! - requestTimeMs;
    if (StreamingConfig.enableQoELogs) {
      debugPrint('[QoE TIMING] episode=$episodeId event=first_frame_rendered TTFF=${ttffMs}ms (target <2000ms 4G, <1000ms WiFi)');
    }
  }

  void markRebufferStart() {
    if (currentRebufferStartTimeMs != null) return;
    currentRebufferStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    rebufferEventCount++;
    if (StreamingConfig.enableQoELogs) {
      debugPrint('[QoE TIMING] episode=$episodeId event=rebuffer_start count=$rebufferEventCount');
    }
  }

  void markRebufferEnd() {
    if (currentRebufferStartTimeMs == null) return;
    final duration = DateTime.now().millisecondsSinceEpoch - currentRebufferStartTimeMs!;
    totalRebufferDurationMs += duration;
    currentRebufferStartTimeMs = null;
    if (StreamingConfig.enableQoELogs) {
      debugPrint('[QoE TIMING] episode=$episodeId event=rebuffer_end stall_duration=${duration}ms total_stall=${totalRebufferDurationMs}ms');
    }
  }

  void markSeekStart() {
    lastSeekStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    if (StreamingConfig.enableQoELogs) {
      debugPrint('[QoE TIMING] episode=$episodeId event=seek_start');
    }
  }

  void markSeekRendered() {
    if (lastSeekStartTimeMs == null) return;
    final latency = DateTime.now().millisecondsSinceEpoch - lastSeekStartTimeMs!;
    lastSeekStartTimeMs = null;
    if (StreamingConfig.enableQoELogs) {
      debugPrint('[QoE TIMING] episode=$episodeId event=seek_rendered latency=${latency}ms (target <1000ms)');
    }
  }

  double calculateRebufferRatio(int activePlaybackMs) {
    if (activePlaybackMs <= 0) return 0.0;
    return (totalRebufferDurationMs / (activePlaybackMs + totalRebufferDurationMs)) * 100.0;
  }
}
