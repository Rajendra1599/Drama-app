import 'package:flutter_test/flutter_test.dart';
import 'package:microdrama_app/config/streaming_config.dart';

void main() {
  group('Prefetch Decision Logic Tests', () {
    test('Should NOT trigger prefetch when progress is under 75% and remaining > 60s', () {
      const int durationSec = 200;
      const int currentPosSec = 50; // 25% watched, 150s remaining
      final double progress = currentPosSec / durationSec;
      final int remainingSec = durationSec - currentPosSec;

      final bool shouldPrefetch = progress >= StreamingConfig.prefetchThresholdPercent ||
          remainingSec <= StreamingConfig.prefetchRemainingSeconds;

      expect(shouldPrefetch, isFalse);
    });

    test('Should trigger prefetch when progress reaches 75%', () {
      const int durationSec = 120;
      const int currentPosSec = 90; // 75% watched, 30s remaining
      final double progress = currentPosSec / durationSec;
      final int remainingSec = durationSec - currentPosSec;

      final bool shouldPrefetch = progress >= StreamingConfig.prefetchThresholdPercent ||
          remainingSec <= StreamingConfig.prefetchRemainingSeconds;

      expect(shouldPrefetch, isTrue);
    });

    test('Should trigger prefetch when remaining time is 60s or less even if progress < 75%', () {
      const int durationSec = 200;
      const int currentPosSec = 145; // 72.5% watched, 55s remaining
      final double progress = currentPosSec / durationSec;
      final int remainingSec = durationSec - currentPosSec;

      final bool shouldPrefetch = progress >= StreamingConfig.prefetchThresholdPercent ||
          remainingSec <= StreamingConfig.prefetchRemainingSeconds;

      expect(shouldPrefetch, isTrue);
    });

    test('Should respect enableDeferredPrefetch feature flag', () {
      StreamingConfig.enableDeferredPrefetch = false;
      expect(StreamingConfig.enableDeferredPrefetch, isFalse);
      StreamingConfig.enableDeferredPrefetch = true;
      expect(StreamingConfig.enableDeferredPrefetch, isTrue);
    });
  });

  group('QoE Telemetry & Rebuffer Calculation Tests', () {
    test('Calculates rebuffer ratio accurately', () {
      final metrics = PlaybackQoEMetrics('test_ep_1');
      metrics.totalRebufferDurationMs = 2000; // 2 seconds stall
      const int activePlaybackMs = 98000; // 98 seconds played

      // Total stream time = 98s + 2s = 100s. Stall = 2s -> 2.0%
      final double ratio = metrics.calculateRebufferRatio(activePlaybackMs);
      expect(ratio, closeTo(2.0, 0.01));
    });

    test('Zero active playback returns 0.0% rebuffer ratio without division by zero', () {
      final metrics = PlaybackQoEMetrics('test_ep_2');
      final double ratio = metrics.calculateRebufferRatio(0);
      expect(ratio, equals(0.0));
    });

    test('Tracks rebuffer start and end durations', () async {
      final metrics = PlaybackQoEMetrics('test_ep_3');
      expect(metrics.rebufferEventCount, equals(0));

      metrics.markRebufferStart();
      expect(metrics.rebufferEventCount, equals(1));
      expect(metrics.currentRebufferStartTimeMs, isNotNull);

      // Simulate 50ms pause
      await Future.delayed(const Duration(milliseconds: 50));
      metrics.markRebufferEnd();

      expect(metrics.currentRebufferStartTimeMs, isNull);
      expect(metrics.totalRebufferDurationMs, greaterThanOrEqualTo(40));
    });
  });

  group('Exponential Backoff & Retry Logic Tests', () {
    int calculateBackoffDelayMs(int attempt, {int baseDelayMs = 400, int maxDelayMs = 5000}) {
      final delay = baseDelayMs * (1 << attempt);
      return delay > maxDelayMs ? maxDelayMs : delay;
    }

    test('Computes correct exponential backoff ladder', () {
      expect(calculateBackoffDelayMs(0), equals(400));
      expect(calculateBackoffDelayMs(1), equals(800));
      expect(calculateBackoffDelayMs(2), equals(1600));
      expect(calculateBackoffDelayMs(3), equals(3200));
      expect(calculateBackoffDelayMs(4), equals(5000)); // capped at maxDelayMs
    });
  });
}
