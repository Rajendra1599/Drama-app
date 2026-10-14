import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drama_provider.dart';
import '../models/drama_series.dart';
import '../widgets/drama_card.dart';
import '../config/theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);
    final watchlist = drama.allSeries
        .where((s) => drama.watchlistIds.contains(s.id))
        .toList();
    final history = drama.watchHistory;

    return Scaffold(
      backgroundColor: AppTheme.dramaBlack,
      appBar: AppBar(
        title: const Text(
          'MY LIBRARY',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.storyTvPink,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textDark,
          tabs: const [
            Tab(text: 'Watchlist'),
            Tab(text: 'Watch History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. WATCHLIST TAB
          watchlist.isEmpty
              ? _EmptyState(
                  icon: Icons.bookmark_border,
                  title: 'Your Watchlist is Empty',
                  subtitle:
                      'Save series to watch later by tapping "+ My List".',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 9 / 16,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final series = watchlist[index];
                    return PureStoryThumbnailCard(
                      series: series,
                      onTap: () => drama.openDramaDetail(series.id),
                    );
                  },
                ),

          // 2. WATCH HISTORY TAB
          history.isEmpty
              ? _EmptyState(
                  icon: Icons.history,
                  title: 'No Watch History Yet',
                  subtitle:
                      'Episodes you stream will automatically appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    DramaSeries? series;
                    try {
                      series = drama.allSeries
                          .firstWhere((s) => s.id == item.seriesId);
                    } catch (e) {}

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.dramaCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => drama.startOrResumeSeries(item.seriesId),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_fill,
                                  color: AppTheme.storyTvPink, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      series?.title ?? 'Drama Story',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Watched ${item.progressSeconds}s of ${item.totalSeconds}s • ${item.isCompleted ? 'Completed' : 'In Progress'}',
                                      style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11),
                                    ),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: item.totalSeconds > 0
                                          ? (item.progressSeconds /
                                                  item.totalSeconds)
                                              .clamp(0.0, 1.0)
                                          : 0,
                                      backgroundColor: Colors.white12,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              AppTheme.storyTvPink),
                                      minHeight: 3,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.play_arrow,
                                    color: Colors.white),
                                onPressed: () =>
                                    drama.startOrResumeSeries(item.seriesId),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
