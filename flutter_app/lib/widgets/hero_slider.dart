import 'dart:async';
import 'package:flutter/material.dart';
import '../models/drama_series.dart';
import '../config/theme.dart';

class HeroSlider extends StatefulWidget {
  final List<DramaSeries> stories;
  final ValueChanged<String> onWatchNow;
  final ValueChanged<String> onOpenDetails;
  final ValueChanged<String> onToggleWatchlist;
  final bool Function(String) isInWatchlist;

  const HeroSlider({
    super.key,
    required this.stories,
    required this.onWatchNow,
    required this.onOpenDetails,
    required this.onToggleWatchlist,
    required this.isInWatchlist,
  });

  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 0.74 viewportFraction displays a large centered card with partially visible cards on both sides
    _pageController = PageController(initialPage: 0, viewportFraction: 0.74);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(HeroSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stories.length != widget.stories.length) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.stories.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.stories.length <= 1) return;
      final nextIndex = (_currentIndex + 1) % widget.stories.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.stories.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive carousel card height matching the reference aspect ratio
    final sliderHeight = (screenWidth > 600 ? 460.0 : (screenWidth * 1.05)).clamp(370.0, 440.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: sliderHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.stories.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  if (mounted) setState(() => _currentIndex = idx);
                },
                itemBuilder: (context, index) {
                  final series = widget.stories[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double diff = 0.0;
                      if (_pageController.position.haveDimensions) {
                        diff = (index.toDouble() - (_pageController.page ?? _currentIndex.toDouble()));
                      } else {
                        diff = (index - _currentIndex).toDouble();
                      }

                      final absDiff = diff.abs().clamp(0.0, 1.0);
                      // Smooth scale: center card is 1.0, side cards scale down to 0.88
                      final scale = (1.0 - (absDiff * 0.12)).clamp(0.88, 1.0);
                      // Dim side cards to 0.65 for focus on center card
                      final opacity = (1.0 - (absDiff * 0.35)).clamp(0.65, 1.0);

                      return Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      );
                    },
                    child: _buildCard(series),
                  );
                },
              ),

            ],
          ),
        ),

        const SizedBox(height: 14),

        // Dots Indicator below carousel
        _buildDotsIndicator(),
      ],
    );
  }

  Widget _buildCard(DramaSeries series) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.dramaCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onOpenDetails(series.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Poster Image
              Image.network(
                _resolveBannerUrl(series),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return Container(
                    color: AppTheme.dramaDarkSurface,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.storyTvPink),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => _buildFallbackBanner(series),
              ),

              // 2. Dark Vignette Gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.70),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const [0.35, 0.52, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Card Content: Badge, Title & "Watch Now ▶" Button
              Positioned(
                left: 14,
                right: 14,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // "A STORY TV ORIGINAL" Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.storyTvPink,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'A STORY TV ORIGINAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      series.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        height: 1.15,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // "Watch Now ▶" Button
                    ElevatedButton(
                      onPressed: () => widget.onWatchNow(series.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.storyTvPink,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: AppTheme.storyTvPink.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Watch Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.stories.length, (i) {
        final isCurrent = i == _currentIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isCurrent ? 22 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.storyTvPink : Colors.white38,
                borderRadius: BorderRadius.circular(3),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppTheme.storyTvPink.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _resolveBannerUrl(DramaSeries series) {
    final cover = series.coverImageUrl.trim();
    if (cover.isNotEmpty && cover.startsWith('http')) {
      return cover;
    }
    final poster = series.posterUrl.trim();
    if (poster.isNotEmpty && poster.startsWith('http')) {
      return poster;
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800';
  }

  Widget _buildFallbackBanner(DramaSeries series) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B1055), Color(0xFF7597DE), Color(0xFF14141E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                series.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
