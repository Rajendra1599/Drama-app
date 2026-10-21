import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_role.dart';
import '../models/episode.dart';
import '../providers/drama_provider.dart';
import '../widgets/episodes_sheet.dart';
import '../services/web_video_interop.dart';
import '../services/rewarded_ad_manager.dart';
import '../services/api_service.dart';
import '../models/drama_series.dart';
import '../config/theme.dart';
import '../config/streaming_config.dart';

class VerticalPlayerScreen extends StatefulWidget {
  const VerticalPlayerScreen({super.key});

  /// Pre-buffers video stream in background for zero-latency startup (<300ms)
  static void prebufferVideoUrl(String rawUrl) => _VerticalPlayerScreenState.prebufferVideoUrl(rawUrl);

  @override
  State<VerticalPlayerScreen> createState() => _VerticalPlayerScreenState();
}

class _VerticalPlayerScreenState extends State<VerticalPlayerScreen> with WidgetsBindingObserver {
  PageController? _pageController;
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  String? _targetLoadingUrl;
  bool _isMuted = false;
  final bool _controlsVisible = true;
  String? _loadedEpisodeId;
  String? _failedEpisodeId;
  String? _playerErrorMessage;
  bool _isRefreshingToken = false;
  int _currentEpisodeNum = 1;
  bool _hasPrefetchedNextEpisode = false;

  // Race-condition prevention & memory management
  int _initSequenceId = 0;
  final Set<VideoPlayerController> _allocatedControllers = {};

  // Global Background Pre-Buffering for Instant TikTok/Reels Style Playback (<300ms)
  static VideoPlayerController? _prebufferedNextController;
  static String? _prebufferedNextUrl;

  bool _showAnimatedIcon = false;
  bool _lastActionWasPlay = true;
  Timer? _iconAnimationTimer;
  bool _showHeartAnimation = false;
  Timer? _heartTimer;

  bool _showRewindAnimation = false;
  bool _showForwardAnimation = false;
  Timer? _seekAnimationTimer;

  // Lifecycle & Rewarded Ad State
  bool _isUnlockingWithAd = false;
  String? _adErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final drama = Provider.of<DramaProvider>(context, listen: false);
    _currentEpisodeNum = drama.activeEpisodeNumber;
    _pageController = PageController(initialPage: (_currentEpisodeNum - 1).clamp(0, 500));

    if (kIsWeb) {
      WebVideoInterop.setupVideoClickHandlers();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndInitVideo(drama);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _videoController?.pause();
      if (mounted) setState(() {});
    }
  }

  void _stopAndMuteCurrentVideo() {
    final c = _videoController;
    if (c != null) {
      try {
        c.setVolume(0.0);
        c.pause();
      } catch (_) {}
    }
    for (final ctrl in List<VideoPlayerController>.from(_allocatedControllers)) {
      if (ctrl != _prebufferedNextController) {
        try {
          ctrl.setVolume(0.0);
          ctrl.pause();
        } catch (_) {}
      }
    }
    if (kIsWeb) {
      WebVideoInterop.pauseAllWebVideos();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final drama = Provider.of<DramaProvider>(context, listen: false);
    if (drama.currentScreen != AppScreen.player) {
      _cleanupAndStopVideo();
      return;
    }

    if (_currentEpisodeNum != drama.activeEpisodeNumber) {
      _stopAndMuteCurrentVideo();
      _currentEpisodeNum = drama.activeEpisodeNumber;
      if (_pageController != null && _pageController!.hasClients) {
        if (_pageController!.page?.round() != _currentEpisodeNum - 1) {
          _pageController!.animateToPage(
            _currentEpisodeNum - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final ep = drama.currentEpisode;
        final bool isAlreadyHandled = ep != null && _loadedEpisodeId == ep.id && (_videoController != null || _isConnecting || _failedEpisodeId == ep.id);
        if (ep != null && !isAlreadyHandled) {
          _checkAndInitVideo(drama);
        }
      }
    });
  }

  void _cleanupAndStopVideo({bool notify = true}) {
    _initSequenceId++; // Invalidate any running async inits
    _isConnecting = false;
    _targetLoadingUrl = null;
    _loadedEpisodeId = null;
    _failedEpisodeId = null;
    final c = _videoController;
    _videoController = null;
    _isInitialized = false;

    if (c != null) {
      try {
        c.setVolume(0.0);
        c.pause();
        c.dispose();
      } catch (_) {}
      _allocatedControllers.remove(c);
    }
    for (final ctrl in List<VideoPlayerController>.from(_allocatedControllers)) {
      try {
        ctrl.setVolume(0.0);
        ctrl.pause();
        ctrl.dispose();
      } catch (_) {}
    }
    _allocatedControllers.clear();

    if (kIsWeb) {
      WebVideoInterop.pauseAllWebVideos();
    }

    // Never call setState during dispose or unmount lifecycle!
    if (notify && mounted && !_isDisposed) {
      setState(() {});
    }
    if (c != null) {
      try {
        if (c.value.isInitialized) {
          final pos = c.value.position.inSeconds;
          final dur = c.value.duration.inSeconds;
          if (dur > 0) {
            final drama = Provider.of<DramaProvider>(context, listen: false);
            final sId = drama.selectedSeriesId;
            final ep = drama.currentEpisode;
            if (sId != null && ep != null) {
              drama.recordWatchProgress(
                seriesId: sId,
                episodeId: ep.id,
                progressSeconds: pos,
                totalSeconds: dur,
              );
            }
          }
        }
      } catch (_) {}
    }

    // Clean up pre-buffered controller
    final oldPre = _prebufferedNextController;
    _prebufferedNextController = null;
    _prebufferedNextUrl = null;
    if (oldPre != null) {
      try {
        oldPre.pause();
        oldPre.dispose();
      } catch (_) {}
    }

    // Force terminate & dispose ALL allocated controllers
    for (final ctrl in _allocatedControllers) {
      try {
        ctrl.pause();
        ctrl.setVolume(0.0);
        ctrl.dispose();
      } catch (e) {
        debugPrint('🎬 [PLAYER] Error disposing controller in pool: $e');
      }
    }
    _allocatedControllers.clear();

    if (kIsWeb) {
      WebVideoInterop.pauseAllWebVideos();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _iconAnimationTimer?.cancel();
    _heartTimer?.cancel();
    _seekAnimationTimer?.cancel();
    _cleanupAndStopVideo(notify: false);
    _pageController?.dispose();
    super.dispose();
  }

  void _unlockEpisodeWithRewardedAd(DramaProvider drama, DramaSeries series, Episode ep) {
    if (_isUnlockingWithAd) return;
    setState(() {
      _isUnlockingWithAd = true;
      _adErrorMessage = null;
    });

    RewardedAdManager.instance.showRewardedAd(
      context: context,
      onUserEarnedReward: () async {
        debugPrint('🎉 [VerticalPlayer] Rewarded ad completed! Unlocking Episode ${ep.episodeNumber}');
        await drama.unlockEpisodeWithAd(series.id, ep.episodeNumber);
        if (mounted) {
          setState(() {
            _isUnlockingWithAd = false;
            _adErrorMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Text('Episode ${ep.episodeNumber} Unlocked! Enjoy streaming.'),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E28),
              duration: const Duration(seconds: 2),
            ),
          );
          // Auto-play the unlocked episode
          _checkAndInitVideo(drama, ep);
        }
      },
      onAdDismissed: () {
        if (mounted) {
          setState(() => _isUnlockingWithAd = false);
        }
      },
      onAdFailed: (error) {
        if (mounted) {
          setState(() {
            _isUnlockingWithAd = false;
            _adErrorMessage = error;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error)),
                ],
              ),
              backgroundColor: const Color(0xFF261214),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'RETRY',
                textColor: AppTheme.storyTvPink,
                onPressed: () => _unlockEpisodeWithRewardedAd(drama, series, ep),
              ),
            ),
          );
        }
      },
    );
  }

  void _pauseForLockedEpisode(Episode lockedEp) {
    _initSequenceId++; // Invalidate any running async inits
    _isConnecting = false;
    _targetLoadingUrl = null;
    _loadedEpisodeId = lockedEp.id; // Mark episode handled so build() does not re-trigger in a loop
    final c = _videoController;
    _videoController = null;
    _isInitialized = false;

    if (c != null) {
      try {
        c.pause();
        c.setVolume(0.0);
        c.dispose();
      } catch (_) {}
      _allocatedControllers.remove(c);
    }

    for (final ctrl in List<VideoPlayerController>.from(_allocatedControllers)) {
      try {
        ctrl.pause();
        ctrl.setVolume(0.0);
        ctrl.dispose();
      } catch (_) {}
    }
    _allocatedControllers.clear();

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  static String _canonicalUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final qIdx = trimmed.indexOf('?');
    return qIdx != -1 ? trimmed.substring(0, qIdx) : trimmed;
  }

  static Uri _buildSafeVideoUri(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.parse(Uri.encodeFull(rawUrl));
  }

  void _checkAndInitVideo([DramaProvider? dramaProvider, Episode? targetEpisode]) {
    if (!mounted || _isDisposed) return;
    final drama = dramaProvider ?? Provider.of<DramaProvider>(context, listen: false);
    final series = drama.selectedSeries;
    final ep = targetEpisode ?? drama.currentEpisode;
    if (ep == null || series == null) {
      debugPrint('🎬 [PLAYER] currentEpisode or series is null');
      return;
    }

    // Check if this episode is locked by paywall
    final isLocked = drama.isEpisodePaywallLocked(ep.episodeNumber, seriesId: series.id);
    if (isLocked) {
      debugPrint('🎬 [PLAYER] Episode ${ep.episodeNumber} is locked behind Paywall');
      _pauseForLockedEpisode(ep);
      return;
    }

    // Prevent duplicate initializations if already loaded, actively connecting, or failed
    final bool isSameEp = _loadedEpisodeId == ep.id;
    final bool isAlreadyHandled = isSameEp && (_videoController != null || _isConnecting || _failedEpisodeId == ep.id);
    if (isAlreadyHandled) {
      return;
    }

    _loadedEpisodeId = ep.id;
    _failedEpisodeId = null;
    final streamUrl = ep.playStreamUrl;
    ApiService.prewarmCdnConnection(streamUrl);
    _initializePlayer(streamUrl);
  }

  static String _optimizeVideoUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return url;
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  static final Map<String, VideoPlayerController> _prebufferedPool = {};

  static void prebufferVideoUrl(String rawUrl) async {
    final nextUrl = _optimizeVideoUrl(rawUrl);
    if (nextUrl.isEmpty) return;

    final canonicalNext = _canonicalUrl(nextUrl);
    if (_prebufferedPool.containsKey(canonicalNext)) {
      final existing = _prebufferedPool[canonicalNext];
      if (existing != null && existing.value.isInitialized) {
        return;
      }
    }

    try {
      final safePreUri = _buildSafeVideoUri(nextUrl);
      debugPrint('[PLAYER PRELOAD <30ms]\nstate=initializing\nhost=${safePreUri.host}\npath=${safePreUri.path}');
      final preCtrl = VideoPlayerController.networkUrl(
        safePreUri,
        httpHeaders: const {'Connection': 'keep-alive'},
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await preCtrl.initialize();
      await preCtrl.setLooping(false);
      await preCtrl.setVolume(0.0);

      if (_prebufferedPool.length >= 4) {
        final oldestKey = _prebufferedPool.keys.first;
        final oldest = _prebufferedPool.remove(oldestKey);
        try {
          oldest?.dispose();
        } catch (_) {}
      }

      _prebufferedPool[canonicalNext] = preCtrl;
      _prebufferedNextController = preCtrl;
      _prebufferedNextUrl = nextUrl;
      debugPrint('[PLAYER PRELOAD <30ms]\nstate=ready_chunk_buffered');
    } catch (e) {
      debugPrint('[PLAYER PRELOAD ERROR]\nmessage=${e.toString()}');
    }
  }

  void _triggerDeferredNextPrefetch(DramaProvider drama) {
    if (!mounted || _isDisposed) return;
    try {
      final series = drama.selectedSeries;
      if (series == null) return;
      final allEps = drama.getEpisodesForSeries(series.id);
      final nextIndex = _currentEpisodeNum; // 0-indexed next episode (since _currentEpisodeNum is 1-indexed)
      if (nextIndex < allEps.length) {
        final nextEp = allEps[nextIndex];
        final nextStreamUrl = nextEp.playStreamUrl;
        // Pre-warm next video connection
        ApiService.prewarmCdnConnection(nextStreamUrl);
        if (kIsWeb) {
          WebVideoInterop.preloadVideo(_optimizeVideoUrl(nextStreamUrl));
        } else {
          prebufferVideoUrl(nextStreamUrl);
        }
      }
    } catch (_) {}
  }

  Future<void> _initializePlayer(String rawUrl, {bool isRetryAfter403 = false}) async {
    final trimmedUrl = _optimizeVideoUrl(rawUrl);
    if (trimmedUrl.isEmpty) {
      return;
    }

    if (_isConnecting && _canonicalUrl(_targetLoadingUrl ?? '') == _canonicalUrl(trimmedUrl)) {
      return;
    }

    _isConnecting = true;
    _targetLoadingUrl = trimmedUrl;
    final currentSeq = ++_initSequenceId;

    final drama = Provider.of<DramaProvider>(context, listen: false);
    final ep = drama.currentEpisode;

    final safeUri = _buildSafeVideoUri(trimmedUrl);
    final epNumStr = 'ep_${ep?.episodeNumber ?? _currentEpisodeNum}';
    final canonicalTarget = _canonicalUrl(trimmedUrl);

    // FAST-PATH (<30ms): If Episode 1 or next episode was pre-buffered in pool, start INSTANTLY!
    VideoPlayerController? readyCtrl;
    if (_prebufferedPool.containsKey(canonicalTarget)) {
      readyCtrl = _prebufferedPool.remove(canonicalTarget);
    } else if (_prebufferedNextController != null &&
        _canonicalUrl(_prebufferedNextUrl ?? '') == canonicalTarget) {
      readyCtrl = _prebufferedNextController;
      _prebufferedNextController = null;
      _prebufferedNextUrl = null;
    }

    if (readyCtrl != null) {
      final activeCtrl = readyCtrl;
      if (!activeCtrl.value.isInitialized) {
        try {
          await activeCtrl.initialize();
        } catch (_) {}
      }

      if (!mounted || _isDisposed || currentSeq != _initSequenceId) {
        try {
          activeCtrl.pause();
          activeCtrl.setVolume(0.0);
          activeCtrl.dispose();
          _allocatedControllers.remove(activeCtrl);
        } catch (_) {}
        _isConnecting = false;
        _targetLoadingUrl = null;
        return;
      }

      final oldController = _videoController;
      _videoController = activeCtrl;
      if (oldController != null && oldController != activeCtrl) {
        try {
          oldController.setVolume(0.0);
          oldController.pause();
          oldController.dispose();
          _allocatedControllers.remove(oldController);
        } catch (_) {}
      }

      try {
        await _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
      } catch (_) {}
      _isConnecting = false;
      _targetLoadingUrl = null;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      try {
        await _videoController?.play();
      } catch (_) {}

      final durSec = activeCtrl.value.duration.inSeconds;
      final w = activeCtrl.value.size.width.toInt();
      final h = activeCtrl.value.size.height.toInt();
      debugPrint('[PLAYER FASTPATH <30ms]\nepisode=$epNumStr\nstate=initialized\nduration=${durSec}s\nsize=${w}x$h');
      debugPrint('[PLAYER FASTPATH <30ms]\nepisode=$epNumStr\nstate=playing');

      final qoeMetrics = StreamingConfig.getMetrics(ep?.id ?? epNumStr);
      qoeMetrics.markFirstFrameRendered();

      int lastRecordedSec = -1;
      activeCtrl.addListener(() {
        if (!mounted || _videoController != activeCtrl || currentSeq != _initSequenceId) return;
        final pos = activeCtrl.value.position.inSeconds;
        final dur = activeCtrl.value.duration.inSeconds;

        // QoE Buffer Stall Tracking
        if (activeCtrl.value.isBuffering) {
          qoeMetrics.markRebufferStart();
        } else {
          qoeMetrics.markRebufferEnd();
        }

        // WORK ITEM 3: Next-episode deferred prefetch at 75% watched or last 60s
        if (dur > 0 && !_hasPrefetchedNextEpisode && StreamingConfig.enableDeferredPrefetch) {
          final double progress = pos / dur;
          final int remainingSec = dur - pos;
          if (progress >= StreamingConfig.prefetchThresholdPercent ||
              remainingSec <= StreamingConfig.prefetchRemainingSeconds) {
            _hasPrefetchedNextEpisode = true;
            _triggerDeferredNextPrefetch(drama);
          }
        }

        if (dur > 0 && (pos - lastRecordedSec).abs() >= 2) {
          lastRecordedSec = pos;
          final sId = drama.selectedSeriesId;
          final curEp = drama.currentEpisode;
          if (sId != null && curEp != null) {
            drama.recordWatchProgress(
              seriesId: sId,
              episodeId: curEp.id,
              progressSeconds: pos,
              totalSeconds: dur,
            );
          }
        }
        if (dur > 0 && activeCtrl.value.position >= activeCtrl.value.duration) {
          _onVideoCompleted();
        }
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }

    // CRITICAL: Stop and mute previous video immediately so Episode 1 sound never bleeds into Episode 2!
    final previousController = _videoController;
    _videoController = null;
    if (previousController != null) {
      try {
        previousController.setVolume(0.0);
        previousController.pause();
        previousController.dispose();
        _allocatedControllers.remove(previousController);
      } catch (_) {}
    }

    try {
      debugPrint('[PLAYER]\nepisode=$epNumStr\nstate=initializing\nhost=${safeUri.host}\npath=${safeUri.path}');

      final controller = VideoPlayerController.networkUrl(
        safeUri,
        httpHeaders: const {'Connection': 'keep-alive'},
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _allocatedControllers.add(controller);

      await controller.initialize();

      // Check if stale or user navigated away during async buffer
      if (!mounted || currentSeq != _initSequenceId) {
        try {
          await controller.setVolume(0.0);
          await controller.pause();
          await controller.dispose();
          _allocatedControllers.remove(controller);
        } catch (_) {}
        _isConnecting = false;
        _targetLoadingUrl = null;
        return;
      }

      if (drama.currentScreen != AppScreen.player) {
        try {
          await controller.setVolume(0.0);
          await controller.pause();
          await controller.dispose();
          _allocatedControllers.remove(controller);
        } catch (_) {}
        if (kIsWeb) WebVideoInterop.pauseAllWebVideos();
        _isConnecting = false;
        _targetLoadingUrl = null;
        return;
      }

      _videoController = controller;

      // Purge any lingering orphaned controllers
      for (final ctrl in List<VideoPlayerController>.from(_allocatedControllers)) {
        if (ctrl != _videoController && ctrl != _prebufferedNextController) {
          try {
            ctrl.setVolume(0.0);
            ctrl.pause();
            ctrl.dispose();
            _allocatedControllers.remove(ctrl);
          } catch (_) {}
        }
      }

      try {
        await controller.setLooping(false); // Do not loop: auto-advance or show ad
        await controller.setVolume(_isMuted ? 0.0 : 1.0);
      } catch (_) {}

      _isConnecting = false;
      _targetLoadingUrl = null;

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      try {
        await controller.play();
      } catch (err) {
        try {
          await controller.setVolume(0.0);
          await controller.play();
        } catch (_) {}
      }

      final durSec = controller.value.duration.inSeconds;
      final w = controller.value.size.width.toInt();
      final h = controller.value.size.height.toInt();
      debugPrint('[PLAYER]\nepisode=$epNumStr\nstate=initialized\nduration=${durSec}s\nsize=${w}x$h');
      debugPrint('[PLAYER]\nepisode=$epNumStr\nstate=playing');

      final qoeMetrics = StreamingConfig.getMetrics(ep?.id ?? epNumStr);
      qoeMetrics.markManifestLoaded();
      qoeMetrics.markFirstFrameRendered();

      if (kIsWeb) {
        WebVideoInterop.optimizeWebVideos();
      }

      int lastRecordedSec = -1;
      controller.addListener(() {
        if (!mounted || _videoController != controller || currentSeq != _initSequenceId) return;
        final pos = controller.value.position.inSeconds;
        final dur = controller.value.duration.inSeconds;

        // QoE Buffer Stall Tracking
        if (controller.value.isBuffering) {
          qoeMetrics.markRebufferStart();
        } else {
          qoeMetrics.markRebufferEnd();
        }

        // WORK ITEM 3: Next-episode deferred prefetch at 75% watched or last 60s
        if (dur > 0 && !_hasPrefetchedNextEpisode && StreamingConfig.enableDeferredPrefetch) {
          final double progress = pos / dur;
          final int remainingSec = dur - pos;
          if (progress >= StreamingConfig.prefetchThresholdPercent ||
              remainingSec <= StreamingConfig.prefetchRemainingSeconds) {
            _hasPrefetchedNextEpisode = true;
            _triggerDeferredNextPrefetch(drama);
          }
        }

        if (dur > 0 && (pos - lastRecordedSec).abs() >= 2) {
          lastRecordedSec = pos;
          final sId = drama.selectedSeriesId;
          final curEp = drama.currentEpisode;
          if (sId != null && curEp != null) {
            drama.recordWatchProgress(
              seriesId: sId,
              episodeId: curEp.id,
              progressSeconds: pos,
              totalSeconds: dur,
            );
          }
        }

        // When video reaches end, auto-advance to next episode
        if (dur > 0 && controller.value.position >= controller.value.duration) {
          _onVideoCompleted();
        }
      });
    } catch (e) {
      _isConnecting = false;
      _targetLoadingUrl = null;

      final errStr = e.toString().toLowerCase();
      final bool is403 = errStr.contains('403') ||
          errStr.contains('forbidden') ||
          errStr.contains('response code: 403');

      String errorType = 'UNKNOWN';
      int errorStatus = 0;
      String errorSummary = 'Playback error';

      if (is403) {
        errorType = 'HTTP';
        errorStatus = 403;
        errorSummary = 'Signed URL / CloudFront authentication problem (403)';
      } else if (errStr.contains('404')) {
        errorType = 'HTTP';
        errorStatus = 404;
        errorSummary = 'S3 object key not found on CDN (404)';
      } else if (errStr.contains('416')) {
        errorType = 'HTTP';
        errorStatus = 416;
        errorSummary = 'Byte-range request problem (416)';
      } else if (errStr.contains('500') || errStr.contains('502') || errStr.contains('503') || errStr.contains('504')) {
        errorType = 'HTTP';
        errorStatus = 500;
        errorSummary = 'CloudFront / S3 origin problem (5xx)';
      } else if (errStr.contains('parserexception') || errStr.contains('extractor')) {
        errorType = 'PARSER';
        errorStatus = 0;
        errorSummary = 'MP4 container / moov atom format problem';
      } else if (errStr.contains('decoderexception') || errStr.contains('mediacodec')) {
        errorType = 'DECODER';
        errorStatus = 0;
        errorSummary = 'Codec or hardware device compatibility problem';
      } else if (errStr.contains('timeout') || errStr.contains('socketexception') || errStr.contains('connection')) {
        errorType = 'NETWORK';
        errorStatus = 0;
        errorSummary = 'Network connection timeout / disconnected';
      }

      debugPrint('[PLAYER ERROR]\nepisode=$epNumStr\ntype=$errorType\nstatus=$errorStatus\nmessage=$errorSummary');

      // If HTTP 403 (token expired or rejected by CloudFront) and haven't retried yet:
      if (is403 && !isRetryAfter403 && ep != null && mounted) {
        setState(() {
          _isRefreshingToken = true;
          _playerErrorMessage = 'Video access expired. Refreshing stream...';
        });

        final playback = await ApiService.fetchPlaybackUrl(
          ep.id,
          seriesId: ep.seriesId,
          episodeNumber: ep.episodeNumber,
        );

        if (mounted) {
          setState(() {
            _isRefreshingToken = false;
          });
        }

        if (playback != null && playback['videoUrl'] != null && mounted) {
          final freshUrl = playback['videoUrl'].toString();
          drama.updateEpisodeVideoUrl(ep.seriesId, ep.id, freshUrl);
          _playerErrorMessage = null;
          // Reinitialize player once with fresh signed URL
          return _initializePlayer(freshUrl, isRetryAfter403: true);
        }
      }

      // Categorize error for accurate, professional UI feedback
      _failedEpisodeId = _loadedEpisodeId;
      if (is403) {
        _playerErrorMessage = 'Video access expired. Please tap Retry to refresh credentials.';
      } else if (errStr.contains('404')) {
        _playerErrorMessage = 'Video file not found on CDN (404).';
      } else if (errStr.contains('500') || errStr.contains('502') || errStr.contains('503') || errStr.contains('504')) {
        _playerErrorMessage = 'CDN server temporarily unavailable (5xx).';
      } else if (errStr.contains('timeoutexception') || errStr.contains('socketexception') || errStr.contains('connection')) {
        _playerErrorMessage = 'Network connection issue. Please check your internet connection.';
      } else {
        _playerErrorMessage = 'Playback error. Tap to retry.';
      }

      if (mounted && currentSeq == _initSequenceId) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _onVideoCompleted() {
    if (!mounted) return;
    final drama = Provider.of<DramaProvider>(context, listen: false);
    final series = drama.selectedSeries;
    if (series == null) return;
    final nextEpNum = _currentEpisodeNum + 1;
    final episodes = drama.getEpisodesForSeries(series.id);
    if (nextEpNum <= episodes.length) {
      _stopAndMuteCurrentVideo();
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.animateToPage(
          nextEpNum - 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Last episode of the series: smoothly loop without tearing down the hardware codec surface
      _videoController?.seekTo(Duration.zero);
      _videoController?.play();
    }
  }

  void _seekRelative(Duration delta) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final current = controller.value.position;
    final total = controller.value.duration;
    var target = current + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;

    final epId = _loadedEpisodeId ?? 'ep_$_currentEpisodeNum';
    StreamingConfig.getMetrics(epId).markSeekStart();
    controller.seekTo(target).then((_) {
      StreamingConfig.getMetrics(epId).markSeekRendered();
    });

    _seekAnimationTimer?.cancel();
    if (delta.isNegative) {
      _showRewindAnimation = true;
      _showForwardAnimation = false;
    } else {
      _showForwardAnimation = true;
      _showRewindAnimation = false;
    }
    if (mounted) setState(() {});
    _seekAnimationTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() {
          _showForwardAnimation = false;
          _showRewindAnimation = false;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        _lastActionWasPlay = false;
      } else {
        await controller.play();
        _lastActionWasPlay = true;
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }

    _iconAnimationTimer?.cancel();
    _showAnimatedIcon = true;
    if (mounted) setState(() {});

    _iconAnimationTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showAnimatedIcon = false;
        });
      }
    });
  }

  void _handleDoubleTapLike(String seriesId, String episodeId) {
    final drama = Provider.of<DramaProvider>(context, listen: false);
    if (!drama.isEpisodeLiked(episodeId)) {
      drama.toggleLikeEpisode(seriesId, episodeId);
    }
    _heartTimer?.cancel();
    _showHeartAnimation = true;
    setState(() {});
    _heartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
    });
  }


  void _showCommentsSheet(BuildContext context, DramaProvider drama, String episodeId) {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final comments = drama.getCommentsForEpisode(episodeId);
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF14141C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Comments (${comments.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white60), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, idx) {
                      final c = comments[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.storyTvPink.withValues(alpha: 0.3),
                              child: Text(c.userName[0], style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.userName, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(c.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                drama.likeComment(episodeId, c.id);
                                setSheetState(() {});
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    c.isLikedByUser ? Icons.favorite : Icons.favorite_border,
                                    color: c.isLikedByUser ? AppTheme.storyTvPink : Colors.white54,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${c.likes}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E26),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: textController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.storyTvPink),
                        onPressed: () {
                          if (textController.text.trim().isNotEmpty) {
                            drama.addComment(episodeId, textController.text);
                            textController.clear();
                            setSheetState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEpisodesDrawer(BuildContext context, DramaProvider drama) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EpisodesBottomSheet(
        episodes: drama.currentEpisodes,
        activeEpisodeNumber: drama.activeEpisodeNumber,
        isVip: drama.isVipActive,
        isEpisodeLocked: (epNumber) => drama.isEpisodePaywallLocked(epNumber, seriesId: drama.selectedSeriesId),
        onSelectEpisode: (epNum) {
          Navigator.pop(ctx);
          drama.startOrResumeSeries(drama.selectedSeriesId!, episodeNumber: epNum);
        },
        onUnlockVip: () {
          Navigator.pop(ctx);
          drama.openAutoPayDialog();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);
    final series = drama.selectedSeries;
    final episodes = drama.currentEpisodes;
    final ep = drama.currentEpisode;
    final isLocked = series != null && ep != null ? drama.isEpisodePaywallLocked(ep.episodeNumber) : false;
    final isUnlocked = !isLocked;

    final bool isAlreadyHandled = ep != null && _loadedEpisodeId == ep.id && (_videoController != null || _isConnecting || _failedEpisodeId == ep.id);
    if (ep != null && isUnlocked && !isAlreadyHandled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _checkAndInitVideo(drama, ep);
        }
      });
    }

    if (series != null && episodes.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _videoController?.pause();
              _videoController?.setVolume(0.0);
              drama.navigateBack();
            },
          ),
          title: Text(
            series.title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.storyTvPink),
              SizedBox(height: 16),
              Text(
                'Loading episodes...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (series == null || episodes.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _videoController?.pause();
              _videoController?.setVolume(0.0);
              drama.navigateBack();
            },
          ),
          title: Text(
            series?.title ?? 'Story',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.movie_creation_outlined, size: 60, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  series != null ? 'No Episodes in "${series.title}" Yet' : 'Story Not Found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload episodes with video URLs in the Admin Portal to start streaming.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _videoController?.pause();
                    _videoController?.setVolume(0.0);
                    drama.navigateBack();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.storyTvPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back to Home', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cleanupAndStopVideo();
        drama.navigateBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // As soon as user starts swiping vertically between episodes, silence current audio immediately
            if (notification is ScrollStartNotification && notification.dragDetails != null) {
              _stopAndMuteCurrentVideo();
            }
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: episodes.length,
            onPageChanged: (index) {
              _stopAndMuteCurrentVideo();
              final targetEp = episodes[index];
              _currentEpisodeNum = targetEp.episodeNumber;
              drama.switchEpisode(targetEp.episodeNumber);
              final isLocked = drama.isEpisodePaywallLocked(targetEp.episodeNumber, seriesId: series.id);
              if (isLocked) {
                _pauseForLockedEpisode(targetEp);
              } else {
                _checkAndInitVideo(drama, targetEp);
              }
            },
          itemBuilder: (context, index) {
            final ep = episodes[index];
            final isCurrent = ep.episodeNumber == _currentEpisodeNum;
            final isLocked = drama.isEpisodePaywallLocked(ep.episodeNumber, seriesId: series.id);
            final isUnlocked = !isLocked;

            final String posterImage = ep.thumbnailUrl.isNotEmpty
                ? ep.thumbnailUrl
                : (series.coverImageUrl.isNotEmpty
                    ? series.coverImageUrl
                    : (series.posterUrl.isNotEmpty ? series.posterUrl : ''));

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Instant Poster Thumbnail Background (Prevents black blank screen)
                if (posterImage.isNotEmpty)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: posterImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFF0D0D12)),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF0D0D12)),
                    ),
                  ),

                // 2. Video Player Surface (Full-Screen Edge-to-Edge with Zero Gaps)
                if (isCurrent && _isInitialized && _videoController != null && isUnlocked)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width > 0
                            ? _videoController!.value.size.width
                            : 720,
                        height: _videoController!.value.size.height > 0
                            ? _videoController!.value.size.height
                            : 1280,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                else
                  Container(
                    color: ep.thumbnailUrl.isNotEmpty ? Colors.transparent : const Color(0xFF0D0D12),
                    child: Center(
                      child: isLocked
                          ? const SizedBox.shrink()
                          : _isRefreshingToken
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(color: AppTheme.storyTvPink),
                                    const SizedBox(height: 12),
                                    Text(
                                      _playerErrorMessage ?? 'Refreshing video stream...',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                )
                              : (_failedEpisodeId == ep.id)
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _playerErrorMessage?.contains('expired') == true
                                              ? Icons.access_time_rounded
                                              : Icons.error_outline_rounded,
                                          color: Colors.white70,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Text(
                                            _playerErrorMessage ?? 'Playback error. Tap to retry',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            _failedEpisodeId = null;
                                            _playerErrorMessage = null;
                                            _checkAndInitVideo(drama, ep);
                                          },
                                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                          label: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.storyTvPink,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const CircularProgressIndicator(color: AppTheme.storyTvPink),
                    ),
                  ),

                // Transparent Interactive Touch Target: Double-tap Left (-10s), Double-tap Right (+10s), Single-tap (Play/Pause)
                Positioned.fill(
                  child: Row(
                    children: [
                      // Left section (Rewind 10s on double-tap)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: isLocked ? null : () => _seekRelative(const Duration(seconds: -10)),
                          onTap: isLocked ? null : _togglePlayPause,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      // Center section (Double-tap to like, single tap to play/pause)
                      SizedBox(
                        width: 120,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: isLocked ? null : () => _handleDoubleTapLike(series.id, ep.id),
                          onTap: isLocked ? null : _togglePlayPause,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      // Right section (Forward 10s on double-tap)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: isLocked ? null : () => _seekRelative(const Duration(seconds: 10)),
                          onTap: isLocked ? null : _togglePlayPause,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Rewind -10s Animated Pill Feedback
                if (_showRewindAnimation)
                  Align(
                    alignment: const Alignment(-0.6, 0.0),
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white30, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 6),
                            Text('-10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Forward +10s Animated Pill Feedback
                if (_showForwardAnimation)
                  Align(
                    alignment: const Alignment(0.6, 0.0),
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white30, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('+10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(width: 6),
                            Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Instagram / TikTok Double-Tap Bursting Heart
                if (_showHeartAnimation)
                  IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.2, end: 1.2),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: (1.2 - scale).clamp(0.0, 1.0) * 0.9 + 0.1,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.storyTvPink.withValues(alpha: 0.6),
                                      blurRadius: 30,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: AppTheme.storyTvPink,
                                  size: 96,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Animated Play / Pause Pop Feedback
                if (_showAnimatedIcon)
                  IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 260),
                        tween: Tween(begin: 0.7, end: 1.15),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white30, width: 1.5),
                              ),
                              child: Icon(
                                _lastActionWasPlay ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Persistent Interactive Center Play Icon when paused
                if (_isInitialized && _videoController != null && !_videoController!.value.isPlaying && !isLocked && !_showAnimatedIcon)
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.storyTvPink.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
                        ),
                      ),
                    ),
                  ),

                // 2. Top Gradient Scrim
                if (_controlsVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3. Bottom Gradient Scrim
                if (_controlsVisible)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 180,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Top Header: Back, Series Title, Episode Number & Speed
                if (_controlsVisible)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    right: 12,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // Absorb taps so top bar does not toggle play/pause
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            onPressed: () {
                              _cleanupAndStopVideo();
                              drama.navigateBack();
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  series.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'Episode ${ep.episodeNumber} / ${series.totalEpisodes}  (Swipe ↕ for next)',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          // Speed Selector Button
                          PopupMenuButton<double>(
                            initialValue: drama.playbackSpeed,
                            icon: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '${drama.playbackSpeed}x',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            onSelected: (speed) {
                              drama.setPlaybackSpeed(speed);
                              _videoController?.setPlaybackSpeed(speed);
                            },
                            itemBuilder: (ctx) => [0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                              return PopupMenuItem(value: s, child: Text('${s}x Speed'));
                            }).toList(),
                          ),
                          const SizedBox(width: 4),
                          // Mute / Unmute Button
                          IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: _isMuted ? AppTheme.storyTvPink : Colors.white,
                              size: 22,
                            ),
                            tooltip: _isMuted ? 'Unmute' : 'Mute',
                            onPressed: () {
                              setState(() {
                                _isMuted = !_isMuted;
                              });
                              _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Right Vertical Sidebar (Like, Comments, Episodes, Watchlist)
                if (_controlsVisible)
                  Positioned(
                    right: 16,
                    bottom: 110,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // Absorb taps so sidebar clicks don't toggle play/pause
                      child: Column(
                        children: [
                          _PlayerSideButton(
                            icon: drama.isEpisodeLiked(ep.id) ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                            label: '${ep.likes}',
                            color: drama.isEpisodeLiked(ep.id) ? AppTheme.storyTvPink : Colors.white,
                            onTap: () {
                              drama.toggleLikeEpisode(series.id, ep.id);
                              _heartTimer?.cancel();
                              _showHeartAnimation = true;
                              setState(() {});
                              _heartTimer = Timer(const Duration(milliseconds: 800), () {
                                if (mounted) {
                                  setState(() {
                                    _showHeartAnimation = false;
                                  });
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _PlayerSideButton(
                            icon: Icons.chat_bubble_outline,
                            label: 'Chat',
                            color: Colors.white,
                            onTap: () => _showCommentsSheet(context, drama, ep.id),
                          ),
                          const SizedBox(height: 16),
                          _PlayerSideButton(
                            icon: Icons.playlist_play,
                            label: 'Episodes',
                            color: Colors.white,
                            onTap: () => _showEpisodesDrawer(context, drama),
                          ),
                          const SizedBox(height: 16),
                          _PlayerSideButton(
                            icon: drama.isInWatchlist(series.id) ? Icons.bookmark : Icons.bookmark_border,
                            label: 'List',
                            color: drama.isInWatchlist(series.id) ? AppTheme.storyTvPink : Colors.white,
                            onTap: () => drama.toggleWatchlist(series.id),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 6. Bottom Interactive Scrubber Bar & Episode Timeline
                if (_controlsVisible && _isInitialized && isCurrent && _videoController != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _InteractiveScrubberBar(controller: _videoController!),
                  ),

                // 7. Paywall Overlay (Shown on Episode 6+ when VIP inactive)
                if (isLocked && isCurrent)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.92),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.storyTvPink.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded, color: AppTheme.storyTvPink, size: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Episode ${ep.episodeNumber} is Locked',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Episodes 1–5 are complimentary. Watch a short ad to unlock this episode for free, or activate VIP for ad-free streaming.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 20),

                          // 1. WATCH AD TO UNLOCK (FREE) / RETRY
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isUnlockingWithAd
                                  ? null
                                  : () => _unlockEpisodeWithRewardedAd(drama, series, ep),
                              icon: _isUnlockingWithAd
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Icon(
                                      _adErrorMessage != null
                                          ? Icons.refresh_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                              label: Text(
                                _isUnlockingWithAd
                                    ? 'PREPARING AD...'
                                    : (_adErrorMessage != null
                                        ? 'RETRY WATCHING AD ➔'
                                        : 'WATCH AD TO UNLOCK (FREE)'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _adErrorMessage != null
                                    ? const Color(0xFFD32F2F)
                                    : AppTheme.storyTvPink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          if (_adErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _adErrorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // 2. VIP PASS (NO ADS)
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () => drama.openAutoPayDialog(),
                              icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 18),
                              label: const Text(
                                'VIP PASS (₹1 TRIAL) • NO ADS ➔',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

            );
          },
        ),
      ),
    ),
  );
}
}

class _InteractiveScrubberBar extends StatefulWidget {
  final VideoPlayerController controller;

  const _InteractiveScrubberBar({required this.controller});

  @override
  State<_InteractiveScrubberBar> createState() => _InteractiveScrubberBarState();
}

class _InteractiveScrubberBarState extends State<_InteractiveScrubberBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final totalSeconds = value.duration.inMilliseconds > 0
            ? value.duration.inMilliseconds / 1000.0
            : 1.0;
        final currentSeconds = (value.position.inMilliseconds / 1000.0).clamp(0.0, totalSeconds);
        final sliderValue = _isDragging ? _dragValue : currentSeconds;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Controls Row: -10s, Time indicator, +10s
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  // Quick Rewind Button (-10s)
                  InkWell(
                    onTap: () {
                      final target = value.position - const Duration(seconds: 10);
                      widget.controller.seekTo(target < Duration.zero ? Duration.zero : target);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay_10_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('10s', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(Duration(milliseconds: (sliderValue * 1000).round())),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  Text(
                    _formatDuration(value.duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  // Quick Forward Button (+10s)
                  InkWell(
                    onTap: () {
                      final target = value.position + const Duration(seconds: 10);
                      final dur = value.duration;
                      widget.controller.seekTo(target > dur ? dur : target);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('10s', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.forward_10_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Smooth Slider Track
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppTheme.storyTvPink,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: AppTheme.storyTvPink.withValues(alpha: 0.3),
              ),
              child: Slider(
                value: sliderValue.clamp(0.0, totalSeconds),
                min: 0.0,
                max: totalSeconds,
                onChangeStart: (val) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = val;
                  });
                },
                onChanged: (val) {
                  setState(() {
                    _dragValue = val;
                  });
                },
                onChangeEnd: (val) {
                  setState(() {
                    _isDragging = false;
                  });
                  widget.controller.seekTo(Duration(milliseconds: (val * 1000).round()));
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _PlayerSideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PlayerSideButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
