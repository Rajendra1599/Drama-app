import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drama_provider.dart';
import '../widgets/hero_slider.dart';
import '../widgets/section_header.dart';
import '../widgets/drama_card.dart';
import '../widgets/see_all_sheet.dart';
import '../config/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final drama = Provider.of<DramaProvider>(context);
    final allSeries = drama.allSeries;
    final trending = drama.trendingDramas;
    final popular = drama.popularDramas;
    final newReleases = drama.newReleases;

    return RefreshIndicator(
      color: AppTheme.storyTvPink,
      backgroundColor: AppTheme.dramaDarkSurface,
      onRefresh: () async {
        await drama.refreshCatalog();
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Empty State if no stories exist yet
          if (allSeries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.storyTvPink.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.movie_filter_outlined, color: AppTheme.storyTvPink, size: 34),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Catalog is Clean & Ready',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All mock stories have been removed.\nUse your Admin Web Portal to upload original micro-dramas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => drama.refreshCatalog(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Catalog'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20202C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),

          // ===================================================================
          // 1. HERO SLIDER BANNER (Randomized showcase)
          // ===================================================================
          if (allSeries.isNotEmpty)
            HeroSlider(
              stories: drama.shuffledSeries.take(6).toList(),
              onWatchNow: (id) => drama.startOrResumeSeries(id),
              onOpenDetails: (id) => drama.startOrResumeSeries(id),
              onToggleWatchlist: (id) => drama.toggleWatchlist(id),
              isInWatchlist: (id) => drama.isInWatchlist(id),
            ),
          const SizedBox(height: 12),

          // ===================================================================
          // 2. TOP 10 ON STORYUP
          // ===================================================================
          if (trending.isNotEmpty) ...[
            StoryTvSectionHeader(
              title: 'Top 10 on StoryUp',
              subtitle: 'Most watched microdramas in India today',
              onSeeAll: () => SeeAllDramasSheet.show(
                context,
                title: 'Top 10 on StoryUp',
                subtitle: 'Trending & Most Watched',
                stories: trending,
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: trending.take(10).length,
                itemBuilder: (context, index) {
                  return Top10StoryCard(
                    rank: index + 1,
                    series: trending[index],
                    onTap: () => drama.startOrResumeSeries(trending[index].id),
                  );
                },
              ),
            ),
          ],

          // ===================================================================
          // 3. TRENDING NOW (Randomized / Popular Selection)
          // ===================================================================
          if (popular.isNotEmpty) ...[
            StoryTvSectionHeader(
              title: 'Trending Now',
              subtitle: 'Viral short series taking the internet by storm',
              onSeeAll: () => SeeAllDramasSheet.show(
                context,
                title: 'Trending Now',
                subtitle: 'Viral Short Series',
                stories: popular,
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: popular.length,
                itemBuilder: (context, index) {
                  return PureStoryThumbnailCard(
                    series: popular[index],
                    onTap: () => drama.startOrResumeSeries(popular[index].id),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ===================================================================
          // 4. NEW RELEASES
          // ===================================================================
          if (newReleases.isNotEmpty) ...[
            StoryTvSectionHeader(
              title: 'New Releases',
              subtitle: 'Fresh episodes dropped this week',
              onSeeAll: () => SeeAllDramasSheet.show(
                context,
                title: 'New Releases',
                subtitle: 'Fresh Episodes',
                stories: newReleases,
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: newReleases.length,
                itemBuilder: (context, index) {
                  return PureStoryThumbnailCard(
                    series: newReleases[index],
                    onTap: () => drama.startOrResumeSeries(newReleases[index].id),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ===================================================================
          // 5. ALL UPLOADED STORIES & DRAMAS (Randomized & Shuffled Grid)
          // ===================================================================
          if (allSeries.isNotEmpty) ...[
            StoryTvSectionHeader(
              title: 'All Uploaded Stories',
              subtitle: 'Explore full library of binge-worthy microdramas',
              onSeeAll: () => SeeAllDramasSheet.show(
                context,
                title: 'All Uploaded Stories',
                subtitle: 'Full Library',
                stories: drama.shuffledSeries,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: drama.shuffledSeries.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 9 / 15,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final s = drama.shuffledSeries[index];
                  return PureStoryThumbnailCard(
                    series: s,
                    onTap: () => drama.startOrResumeSeries(s.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
