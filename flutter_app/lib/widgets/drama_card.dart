import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/drama_series.dart';
import '../config/theme.dart';

class PureStoryThumbnailCard extends StatelessWidget {
  final DramaSeries series;
  final VoidCallback onTap;
  final double width;
  final double aspectRatio;

  const PureStoryThumbnailCard({
    super.key,
    required this.series,
    required this.onTap,
    this.width = 112,
    this.aspectRatio = 9 / 13,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster Card with Episode Badge (Expanded to fit available space perfectly)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPosterImage(),

                    // Subtle Bottom Gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            stops: const [0.65, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Top Left: HOT Badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.storyTvPink.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Right: Total Episodes Badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${series.totalEpisodes > 0 ? series.totalEpisodes : 1} EP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),

            // Title
            Text(
              series.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),

            // Rating & Views
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppTheme.dramaGold, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    '${series.rating > 0 ? series.rating : 4.8}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatViews(series.totalViews),
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A24),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.storyTvPink),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF26263A), Color(0xFF14141E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_creation_outlined,
              color: Colors.white38, size: 28),
          const SizedBox(height: 6),
          Text(
            series.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _resolveImageUrl(DramaSeries series) {
    final poster = series.posterUrl.trim();
    if (poster.isNotEmpty && poster.startsWith('http')) return poster;
    final cover = series.coverImageUrl.trim();
    if (cover.isNotEmpty && cover.startsWith('http')) return cover;
    return '';
  }

  Widget _buildPosterImage() {
    final url = _resolveImageUrl(series);
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 360,
        placeholder: (_, __) => _buildPlaceholder(),
        errorWidget: (_, __, ___) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(0)}K';
    return '$views';
  }
}

class Top10StoryCard extends StatelessWidget {
  final int rank;
  final DramaSeries series;
  final VoidCallback onTap;

  const Top10StoryCard({
    super.key,
    required this.rank,
    required this.series,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 122,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Giant Rank Number (Positioned high up, aligning with poster center)
            Positioned(
              left: -4,
              top: 22,
              child: Text(
                '$rank',
                style: GoogleFonts.bebasNeue(
                  fontSize: 86,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3.5
                    ..color = const Color(0xFF6E6E82),
                ),
              ),
            ),
            Positioned(
              left: -4,
              top: 22,
              child: Text(
                '$rank',
                style: GoogleFonts.bebasNeue(
                  fontSize: 86,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0D0D14),
                ),
              ),
            ),

            // 2. Story Poster Card Overlapping on top of the number
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.85),
                            blurRadius: 8,
                            offset: const Offset(-4, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPosterImage(),

                            // Subtle bottom vignette
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.75),
                                    ],
                                    stops: const [0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Top Right Rank Badge
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.storyTvPink,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '#$rank',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),

                            // Total Episodes Badge
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  '${series.totalEpisodes > 0 ? series.totalEpisodes : 12} EP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    series.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Rating & Views
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            color: AppTheme.dramaGold, size: 9.5),
                        const SizedBox(width: 2),
                        Text(
                          '${series.rating > 0 ? series.rating : 4.9}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatViews(series.totalViews),
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveImageUrl(DramaSeries series) {
    final poster = series.posterUrl.trim();
    if (poster.isNotEmpty && poster.startsWith('http')) return poster;
    final cover = series.coverImageUrl.trim();
    if (cover.isNotEmpty && cover.startsWith('http')) return cover;
    return '';
  }

  Widget _buildPosterImage() {
    final url = _resolveImageUrl(series);
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 360,
        placeholder: (_, __) => Container(color: const Color(0xFF1A1A24)),
        errorWidget: (_, __, ___) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF26263A), Color(0xFF14141E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_creation_outlined,
              color: Colors.white38, size: 24),
          const SizedBox(height: 4),
          Text(
            series.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(0)}K';
    return '$views';
  }
}
