import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/user_role.dart';
import '../providers/drama_provider.dart';
import '../widgets/episodes_sheet.dart';
import '../services/web_video_interop.dart';
import '../config/theme.dart';

class VerticalPlayerScreen extends StatefulWidget {
  const VerticalPlayerScreen({super.key});

  @override
  State<VerticalPlayerScreen> createState() => _VerticalPlayerScreenState();
}

class _VerticalPlayerScreenState extends State<VerticalPlayerScreen> with WidgetsBindingObserver {
  PageController? _pageController;
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isMuted = false;
  final bool _controlsVisible = true;
  String? _loadedVideoUrl;
  String? _loadedEpisodeId;
  int _currentEpisodeNum = 1;

  bool _showAnimatedIcon = false;
  bool _lastActionWasPlay = true;
  Timer? _iconAnimationTimer;
  bool _showHeartAnimation = false;
  Timer? _heartTimer;

  bool _showRewindAnimation = false;
  bool _showForwardAnimation = false;
  Timer? _seekAnimationTimer;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final drama = Provider.of<DramaProvider>(context, listen: false);
    if (_currentEpisodeNum != drama.activeEpisodeNumber) {
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
        _checkAndInitVideo(drama);
      }
    });
  }

  void _checkAndInitVideo([DramaProvider? dramaProvider]) {
    if (!mounted) return;
    final drama = dramaProvider ?? Provider.of<DramaProvider>(context, listen: false);
    final ep = drama.currentEpisode;
    if (ep == null) {
      debugPrint('🎬 [PLAYER] currentEpisode is null');
      return;
    }

    // Hard paywall is only active if payment is required (not bypassed) and user is not VIP
    final isPaywallBlocked = drama.isEpisodePaywallLocked(ep.episodeNumber);
    if (isPaywallBlocked) {
      debugPrint('🎬 [PLAYER] Episode ${ep.episodeNumber} is paywall locked');
      _videoController?.pause();
      return;
    }

    if (_loadedEpisodeId != ep.id || _loadedVideoUrl != ep.videoUrl || _videoController == null) {
      _loadedEpisodeId = ep.id;
      _loadedVideoUrl = ep.videoUrl;
      debugPrint('🎬 [PLAYER] Initializing ep #${ep.episodeNumber} (${ep.id}) - URL: ${ep.videoUrl}');
      _initializePlayer(ep.videoUrl);
    }
  }

  Future<void> _initializePlayer(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      debugPrint('🎬 [PLAYER] URL is empty!');
      return;
    }

    final oldController = _videoController;
    _videoController = null;
    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }
    if (oldController != null) {
      try {
        await oldController.pause();
        await oldController.setVolume(0.0);
        await oldController.dispose();
      } catch (e) {
        debugPrint('🎬 [PLAYER] Error disposing old controller: $e');
      }
    }

    try {
      debugPrint('🎬 [PLAYER] Connecting to video: $trimmedUrl');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(trimmedUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      _videoController = controller;
      await controller.initialize();

      if (!mounted) {
        try {
          await controller.pause();
          await controller.setVolume(0.0);
          await controller.dispose();
        } catch (_) {}
        return;
      }

      final drama = Provider.of<DramaProvider>(context, listen: false);
      if (drama.currentScreen != AppScreen.player) {
        try {
          await controller.pause();
          await controller.setVolume(0.0);
        } catch (_) {}
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      setState(() {
        _isInitialized = true;
      });

      await controller.play();
      debugPrint('🎬 [PLAYER] Playing! Size: ${controller.value.size}, Duration: ${controller.value.duration}');

      int lastRecordedSec = -1;
      controller.addListener(() {
        if (!mounted || _videoController != controller) return;
        final pos = controller.value.position.inSeconds;
        final dur = controller.value.duration.inSeconds;
        if (dur > 0 && (pos - lastRecordedSec).abs() >= 2) {
          lastRecordedSec = pos;
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
      });
    } catch (e) {
      debugPrint('🎬 [PLAYER] Video init error: $e');
      const fallbackUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
      if (trimmedUrl != fallbackUrl && mounted) {
        debugPrint('🎬 [PLAYER] Retrying with reliable fallback video stream...');
        _initializePlayer(fallbackUrl);
      }
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
    controller.seekTo(target);

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iconAnimationTimer?.cancel();
    _heartTimer?.cancel();
    _seekAnimationTimer?.cancel();
    try {
      if (_videoController != null && _videoController!.value.isInitialized) {
        final pos = _videoController!.value.position.inSeconds;
        final dur = _videoController!.value.duration.inSeconds;
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
    try {
      _videoController?.pause();
      _videoController?.setVolume(0.0);
      _videoController?.dispose();
    } catch (_) {}
    _pageController?.dispose();
    super.dispose();
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

    if (ep != null && (_loadedEpisodeId != ep.id || _loadedVideoUrl != ep.videoUrl || _videoController == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndInitVideo(drama);
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
        _videoController?.pause();
        _videoController?.setVolume(0.0);
        drama.navigateBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: episodes.length,
          onPageChanged: (index) {
            final targetEp = episodes[index];
            _currentEpisodeNum = targetEp.episodeNumber;
            drama.startOrResumeSeries(series.id, episodeNumber: targetEp.episodeNumber);
          },
          itemBuilder: (context, index) {
            final ep = episodes[index];
            final isCurrent = ep.episodeNumber == drama.activeEpisodeNumber;
            final isLocked = drama.isEpisodePaywallLocked(ep.episodeNumber);

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Video Player Surface (Full-Screen Edge-to-Edge with Zero Gaps)
                if (isCurrent && _isInitialized && _videoController != null && !isLocked)
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
                    color: const Color(0xFF0D0D12),
                    child: Center(
                      child: isLocked
                          ? const SizedBox.shrink()
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
                              _videoController?.pause();
                              _videoController?.setVolume(0.0);
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

                // 8. VIP Paywall Overlay (Triggered on Episode 6+)
                if (isLocked)
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
                              color: AppTheme.storyTvPink.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock, color: AppTheme.storyTvPink, size: 44),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Episode ${ep.episodeNumber} is Locked',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Episodes 1–5 are complimentary. Activate the 1-Day Trial Pass for ₹1 (then ₹599/mo AutoPay) to unlock all episodes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 18),

                          // Pay ₹1 Trial Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => drama.openAutoPayDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.storyTvPink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text(
                                'ACTIVATE 1-DAY TRIAL FOR ₹1 ➔',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
