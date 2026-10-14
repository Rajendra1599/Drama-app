import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/episode.dart';
import '../config/theme.dart';

class EpisodesBottomSheet extends StatelessWidget {
  final List<Episode> episodes;
  final int activeEpisodeNumber;
  final bool isVip;
  final ValueChanged<int> onSelectEpisode;
  final VoidCallback onUnlockVip;

  const EpisodesBottomSheet({
    super.key,
    required this.episodes,
    required this.activeEpisodeNumber,
    required this.isVip,
    required this.onSelectEpisode,
    required this.onUnlockVip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF121218),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Episodes (${episodes.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isVip ? 'VIP UNLOCKED' : 'EP 1-5 FREE',
                  style: TextStyle(
                    color: isVip ? AppTheme.successGreen : AppTheme.storyTvPink,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Episodes List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final ep = episodes[index];
                final isCurrent = ep.episodeNumber == activeEpisodeNumber;
                final isLocked = !isVip && ep.episodeNumber > 5;

                return InkWell(
                  onTap: () {
                    if (isLocked) {
                      onUnlockVip();
                    } else {
                      onSelectEpisode(ep.episodeNumber);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.storyTvPink.withValues(alpha: 0.12)
                          : AppTheme.dramaCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? AppTheme.storyTvPink
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Episode Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: ep.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      color: AppTheme.dramaDarkSurface),
                                  errorWidget: (_, __, ___) => Container(
                                      color: AppTheme.dramaDarkSurface),
                                ),
                                if (isCurrent)
                                  Container(
                                    color: Colors.black45,
                                    child: const Center(
                                      child: Icon(Icons.play_arrow,
                                          color: AppTheme.storyTvPink,
                                          size: 24),
                                    ),
                                  ),
                                if (isLocked)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: Icon(Icons.lock,
                                          color: AppTheme.dramaGold, size: 20),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ep ${ep.episodeNumber}: ${ep.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent
                                      ? AppTheme.storyTvPink
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ep.durationSeconds}s • ${isLocked ? 'VIP Only' : 'Free'}',
                                style: TextStyle(
                                  color: isLocked
                                      ? AppTheme.dramaGold
                                      : AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status Icon
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.storyTvPink.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppTheme.storyTvPink, width: 0.8),
                            ),
                            child: const Text(
                              'UNLOCK',
                              style: TextStyle(
                                color: AppTheme.storyTvPink,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (isCurrent)
                          const Icon(Icons.graphic_eq,
                              color: AppTheme.storyTvPink, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
