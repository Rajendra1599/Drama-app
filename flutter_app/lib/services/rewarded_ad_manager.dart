import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Production Rewarded Video Ad Manager for Episode Unlocking
/// STRICT MONETIZATION POLICY:
/// - Ads are 100% compulsory.
/// - If ad fails, is skipped, or is closed early, the episode is NEVER unlocked.
/// - A "RETRY" prompt is presented so the user must watch the full ad to unlock.
class RewardedAdManager {
  RewardedAdManager._internal();
  static final RewardedAdManager instance = RewardedAdManager._internal();

  // ===========================================================================
  // CONFIG CONSTANTS (Official AdMob Rewarded Ad Test Units)
  // ===========================================================================
  static const String _kTestAdUnitAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _kTestAdUnitIOS =
      'ca-app-pub-3940256099942544/1712485313';

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _isAdShowing = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  bool get isAdLoaded => _rewardedAd != null;
  bool get isAdLoading => _isAdLoading;
  bool get isAdShowing => _isAdShowing;

  String get _adUnitId {
    if (kIsWeb) return '';
    return Platform.isAndroid ? _kTestAdUnitAndroid : _kTestAdUnitIOS;
  }

  /// Initialize and start preloading the first rewarded ad
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('ℹ️ [RewardedAdManager] Web platform initialized with Web Rewarded Ad Simulation.');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      debugPrint('✅ [RewardedAdManager] Google Mobile Ads SDK Initialized.');
    } catch (e) {
      debugPrint('⚠️ [RewardedAdManager] MobileAds initialize error: $e');
    }

    preloadRewardedAd();
  }

  /// Preload the next rewarded ad in the background
  void preloadRewardedAd() {
    if (kIsWeb || _isAdLoading || _rewardedAd != null) return;

    _isAdLoading = true;
    debugPrint('🔄 [RewardedAdManager] Preloading Rewarded Ad for episode unlocks...');

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('🎯 [RewardedAdManager] Rewarded Ad preloaded successfully!');
          _rewardedAd = ad;
          _isAdLoading = false;
          _retryAttempt = 0;
          _retryTimer?.cancel();
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ [RewardedAdManager] Rewarded Ad load failed: ${error.message} (code ${error.code})');
          _rewardedAd = null;
          _isAdLoading = false;
          _scheduleRetry();
        },
      ),
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryAttempt++;
    final delaySeconds = (_retryAttempt * 4).clamp(4, 30);
    debugPrint('⏳ [RewardedAdManager] Retrying ad load in $delaySeconds seconds (Attempt #$_retryAttempt)...');
    _retryTimer = Timer(Duration(seconds: delaySeconds), preloadRewardedAd);
  }

  /// Displays the Rewarded Ad to unlock an episode
  /// STRICT:
  /// - ONLY calls [onUserEarnedReward] if the user fully watches the ad!
  /// - Calls [onAdFailed] with an error message so UI shows "RETRY" if ad fails or is cancelled!
  Future<void> showRewardedAd({
    BuildContext? context,
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdDismissed,
    Function(String error)? onAdFailed,
  }) async {
    // -------------------------------------------------------------------------
    // WEB PLATFORM: Interactive 10-Second Non-Skippable Web Rewarded Ad
    // -------------------------------------------------------------------------
    if (kIsWeb) {
      if (context != null) {
        _showWebRewardedAd(
          context: context,
          onUserEarnedReward: onUserEarnedReward,
          onAdDismissed: onAdDismissed,
          onAdFailed: onAdFailed,
        );
      } else {
        onAdFailed?.call('Web browser context required. Tap Retry.');
      }
      return;
    }

    // -------------------------------------------------------------------------
    // MOBILE PLATFORM: Google Mobile Ads (AdMob)
    // -------------------------------------------------------------------------
    if (_rewardedAd == null) {
      debugPrint('⚠️ [RewardedAdManager] Ad not loaded yet. Attempting fresh load...');
      _isAdLoading = true;
      RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoading = false;
            // Now show the freshly loaded ad
            showRewardedAd(
              context: context,
              onUserEarnedReward: onUserEarnedReward,
              onAdDismissed: onAdDismissed,
              onAdFailed: onAdFailed,
            );
          },
          onAdFailedToLoad: (error) {
            _isAdLoading = false;
            debugPrint('❌ [RewardedAdManager] On-demand ad load failed: ${error.message}');
            // STRICT: Do NOT unlock! Tell UI to show RETRY.
            onAdFailed?.call('Ad could not be loaded. Please tap Retry.');
            onAdDismissed?.call();
          },
        ),
      );
      return;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null; // Consume the loaded ad
    _isAdShowing = true;
    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 [RewardedAdManager] Rewarded Ad started on screen.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('🎬 [RewardedAdManager] Rewarded Ad dismissed.');
        _isAdShowing = false;
        ad.dispose();
        if (rewardEarned) {
          onUserEarnedReward();
        } else {
          // STRICT: User closed ad before finishing!
          onAdFailed?.call('Ad was closed before completing. Please watch full ad to unlock.');
        }
        onAdDismissed?.call();
        // Preload next ad
        preloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('⚠️ [RewardedAdManager] Failed to show Rewarded Ad: ${error.message}');
        _isAdShowing = false;
        ad.dispose();
        // STRICT: Do NOT unlock! Prompt retry.
        onAdFailed?.call('Ad failed to play (${error.message}). Please tap Retry.');
        onAdDismissed?.call();
        preloadRewardedAd();
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (adWithoutView, reward) {
          debugPrint('🎁 [RewardedAdManager] User earned reward! Type: ${reward.type}, Amount: ${reward.amount}');
          rewardEarned = true;
        },
      );
    } catch (e) {
      debugPrint('⚠️ [RewardedAdManager] Exception during ad.show(): $e');
      _isAdShowing = false;
      onAdFailed?.call('Ad error: $e. Please tap Retry.');
      onAdDismissed?.call();
      preloadRewardedAd();
    }
  }

  /// Interactive Web Rewarded Ad Dialog (10-second non-skippable countdown)
  void _showWebRewardedAd({
    required BuildContext context,
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdDismissed,
    Function(String error)? onAdFailed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _WebRewardedAdModal(
          onRewardEarned: () {
            Navigator.of(dialogCtx, rootNavigator: true).pop();
            onUserEarnedReward();
            onAdDismissed?.call();
          },
          onAdCancelled: () {
            Navigator.of(dialogCtx, rootNavigator: true).pop();
            onAdFailed?.call('Ad was closed early. Tap Retry to watch ad and unlock.');
            onAdDismissed?.call();
          },
        );
      },
    );
  }

  void dispose() {
    _retryTimer?.cancel();
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}

/// Fullscreen-style Web Rewarded Video Ad Modal with 10-second countdown
class _WebRewardedAdModal extends StatefulWidget {
  final VoidCallback onRewardEarned;
  final VoidCallback onAdCancelled;

  const _WebRewardedAdModal({
    required this.onRewardEarned,
    required this.onAdCancelled,
  });

  @override
  State<_WebRewardedAdModal> createState() => _WebRewardedAdModalState();
}

class _WebRewardedAdModalState extends State<_WebRewardedAdModal> {
  static const int _kTotalSeconds = 30;
  int _remainingSeconds = _kTotalSeconds;
  Timer? _countdownTimer;
  bool _rewardUnlocked = false;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _rewardUnlocked = true;
        });
        // Auto-grant reward after brief celebration delay
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onRewardEarned();
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (1.0 - (_remainingSeconds / _kTotalSeconds)).clamp(0.0, 1.0);

    return PopScope(
      canPop: _rewardUnlocked, // Strictly Non-Skippable: Cannot close or press back during 30s
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_rewardUnlocked) {
          debugPrint('🔒 [WebRewardedAd] Non-skippable ad in progress. Must watch full 30 seconds.');
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101016),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.8), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE50914).withValues(alpha: 0.35),
                  blurRadius: 35,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar: Badge & 30s Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AD • 0:30',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'NON-SKIPPABLE',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _rewardUnlocked ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                            color: _rewardUnlocked ? Colors.greenAccent : Colors.amberAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _rewardUnlocked
                                ? 'UNLOCKED!'
                                : '0:${_remainingSeconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Ad Video Surface / Visual Commercial Display
                Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF260D1A), Color(0xFF0F1E33)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (_rewardUnlocked ? Colors.greenAccent : const Color(0xFFE50914))
                                  .withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: _rewardUnlocked
                                ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 44)
                                : const Icon(Icons.play_arrow_rounded, color: Color(0xFFE50914), size: 44),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _rewardUnlocked ? '🎉 Reward Earned!' : 'StoryUp Premium Sponsor Video',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _rewardUnlocked
                                ? 'Unlocking your episode now...'
                                : 'Playing 30-Second Commercial to unlock Episode...',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 30-Second Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _rewardUnlocked ? Colors.greenAccent : const Color(0xFFE50914),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Non-Skippable Notice Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _rewardUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        color: _rewardUnlocked ? Colors.greenAccent : Colors.amberAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _rewardUnlocked
                            ? 'Episode unlocked! Starting video...'
                            : 'Watch all 30 seconds. Video cannot be skipped.',
                        style: TextStyle(
                          color: _rewardUnlocked ? Colors.greenAccent : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Emergency Exit Button (Explicitly does NOT unlock)
                if (!_rewardUnlocked)
                  TextButton(
                    onPressed: widget.onAdCancelled,
                    child: const Text(
                      'Cancel & Leave (Episode remains locked)',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
