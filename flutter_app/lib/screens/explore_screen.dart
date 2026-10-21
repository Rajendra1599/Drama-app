import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/drama_series.dart';
import '../models/user_role.dart';
import '../providers/drama_provider.dart';
import '../services/web_video_interop.dart';
import '../services/api_service.dart';
import '../widgets/episodes_sheet.dart';
import '../config/theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with WidgetsBindingObserver {
  PageController? _pageController;
  int _currentPageIndex = 0;
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  String? _currentLoadedUrl;
  bool _isMuted = false;

  bool _showHeartAnimation = false;
  Timer? _heartTimer;

  static const List<String> _sampleStoryVideos = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);

    if (kIsWeb) {
      WebVideoInterop.setupVideoClickHandlers();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoPlayCurrentStory();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _videoController?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartTimer?.cancel();
    _pageController?.dispose();
    try {
      _videoController?.pause();
      _videoController?.setVolume(0.0);
      _videoController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final drama = Provider.of<DramaProvider>(context);
    final isExploreActive = drama.currentScreen == AppScreen.explore;

    if (!isExploreActive) {
      _videoController?.pause();
    } else {
      if (_videoController != null && _videoController!.value.isInitialized) {
        if (!_videoController!.value.isPlaying) {
          _videoController?.play().catchError((e) {
            debugPrint('Autoplay handled: $e');
          });
        }
      } else {
        _checkAndAutoPlayCurrentStory();
      }
    }
  }

  String _getVideoUrlForSeries(DramaSeries series, DramaProvider drama, int index) {
    final episodes = drama.getEpisodesForSeries(series.id);
    if (episodes.isNotEmpty && episodes.first.videoUrl.isNotEmpty) {
      return episodes.first.videoUrl;
    }
    return _sampleStoryVideos[index % _sampleStoryVideos.length];
  }

  void _checkAndAutoPlayCurrentStory() {
    final drama = Provider.of<DramaProvider>(context, listen: false);
    if (drama.currentScreen != AppScreen.explore) return;
    if (drama.allSeries.isEmpty) return;
    if (_currentPageIndex >= drama.allSeries.length) return;

    final currentSeries = drama.allSeries[_currentPageIndex];
    final targetUrl = _getVideoUrlForSeries(currentSeries, drama, _currentPageIndex);

    if (_currentLoadedUrl != targetUrl) {
      _initAndPlayVideo(targetUrl);
    }
  }

  static String _optimizeVideoUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return url;
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  Future<void> _initAndPlayVideo(String url) async {
    _currentLoadedUrl = url;
    if (_videoController != null) {
      try {
        await _videoController!.pause();
        await _videoController!.setVolume(0.0);
        await _videoController!.dispose();
      } catch (_) {}
    }
    _videoController = null;
    _isInitialized = false;
    if (mounted) setState(() {});

    final optimizedUrl = _optimizeVideoUrl(url);
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(optimizedUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _videoController = controller;

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final drama = Provider.of<DramaProvider>(context, listen: false);
      if (drama.currentScreen != AppScreen.explore) {
        await controller.pause();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.play().catchError((e) {
        debugPrint('Autoplay handled: $e');
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (_) {}
  }

  void _showEpisodesForSeries(BuildContext context, DramaSeries series, DramaProvider drama) {
    var episodes = drama.getEpisodesForSeries(series.id);
    if (episodes.isEmpty) {
      drama.loadEpisodesForSeries(series.id);
      final count = series.totalEpisodes > 0 ? series.totalEpisodes : 10;
      episodes = ApiService.getEpisodesForSeries(series.id, count);
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EpisodesBottomSheet(
        episodes: episodes,
        activeEpisodeNumber: 1,
        isVip: drama.isVipActive,
        isEpisodeLocked: (epNumber) => drama.isEpisodePaywallLocked(epNumber, seriesId: series.id),
        onSelectEpisode: (epNum) {
          Navigator.pop(ctx);
          drama.startOrResumeSeries(series.id, episodeNumber: epNum);
        },
        onUnlockVip: () {
          Navigator.pop(ctx);
          drama.openAutoPayDialog();
        },
      ),
    );
  }


  void _handleDoubleTapLike(String seriesId, DramaProvider drama) {
    drama.toggleLikeSeries(seriesId);
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

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatLikes(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }


  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);
    final allSeries = drama.allSeries;

    if (allSeries.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.dramaBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.video_library_outlined, size: 56, color: Colors.white24),
              SizedBox(height: 12),
              Text(
                'No Stories Uploaded Yet',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Upload dramas from the Admin Portal to watch here',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: allSeries.length,
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });
          final series = allSeries[index];
          final targetUrl = _getVideoUrlForSeries(series, drama, index);
          _initAndPlayVideo(targetUrl);
        },
        itemBuilder: (context, index) {
          final series = allSeries[index];
          final isInList = drama.isInWatchlist(series.id);
          final isCurrent = index == _currentPageIndex;

          final coverUrl = series.coverImageUrl.isNotEmpty ? series.coverImageUrl : series.posterUrl;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Clicking anywhere on the video in Explore tab shows all episodes of that story
            onTap: () => _showEpisodesForSeries(context, series, drama),
            onDoubleTap: () => _handleDoubleTapLike(series.id, drama),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Cover Image Placeholder
                CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  memCacheHeight: 1400,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF0D0D15),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.storyTvPink, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E1E2C), Color(0xFF0F0F16)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 64),
                    ),
                  ),
                ),

                // 2. High-Performance HTML5 / Native Video Player (Full-Screen Edge-to-Edge)
                if (isCurrent && _isInitialized && _videoController != null)
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
                  ),

                // 3. Cinematic Vignette & Bottom Scrim
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),

                // 4. Header Bar: LIVE EXPLORE Tag & Audio Mute/Unmute
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.storyTvPink,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'EXPLORE FEED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Audio Toggle
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleMute,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Double-Tap Bursting Heart Animation
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

                // 7. Right Action Column (Like, Bookmark, Episodes, Share, Info)
                Positioned(
                  right: 14,
                  bottom: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // Absorb taps
                    child: Column(
                      children: [
                        // Real Like Button
                        _VerticalActionButton(
                          icon: Icons.favorite_rounded,
                          label: _formatLikes(series.totalLikes),
                          color: AppTheme.storyTvPink,
                          onTap: () => _handleDoubleTapLike(series.id, drama),
                        ),
                        const SizedBox(height: 16),

                        // Episodes Sheet Trigger
                        _VerticalActionButton(
                          icon: Icons.video_library_rounded,
                          label: 'Episodes',
                          color: AppTheme.storyTvPink,
                          onTap: () => _showEpisodesForSeries(context, series, drama),
                        ),
                        const SizedBox(height: 16),

                        // My List Toggle
                        _VerticalActionButton(
                          icon: isInList ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          label: 'My List',
                          color: isInList ? AppTheme.storyTvPink : Colors.white,
                          onTap: () => drama.toggleWatchlist(series.id),
                        ),
                        const SizedBox(height: 16),

                        // Share
                        _VerticalActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          color: Colors.white,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied to clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Details Info
                        _VerticalActionButton(
                          icon: Icons.info_outline_rounded,
                          label: 'Info',
                          color: Colors.white,
                          onTap: () => drama.openDramaDetail(series.id),
                        ),
                      ],
                    ),
                  ),
                ),

                // 8. Bottom Story Info & "All Episodes" Action
                Positioned(
                  left: 16,
                  right: 90,
                  bottom: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showEpisodesForSeries(context, series, drama),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Episode Count & Genre Badges
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.storyTvPink,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${series.totalEpisodes > 0 ? series.totalEpisodes : 1} EPISODES',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (series.genres.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  series.genres.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Series Title
                        Text(
                          series.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Synopsis Preview
                        if (series.synopsis.isNotEmpty)
                          Text(
                            series.synopsis,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        const SizedBox(height: 14),

                        // Primary CTA to Watch in Full Vertical Player
                        ElevatedButton.icon(
                          onPressed: () => drama.startOrResumeSeries(series.id, episodeNumber: 1),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                          label: const Text(
                            'Watch Episode 1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.storyTvPink,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 4,
                            shadowColor: AppTheme.storyTvPink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VerticalActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _VerticalActionButton({
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
