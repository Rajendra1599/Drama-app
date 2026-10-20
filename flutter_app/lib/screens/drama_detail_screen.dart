import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/drama_provider.dart';
import '../config/theme.dart';

class DramaDetailScreen extends StatefulWidget {
  const DramaDetailScreen({super.key});

  @override
  State<DramaDetailScreen> createState() => _DramaDetailScreenState();
}

class _DramaDetailScreenState extends State<DramaDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _showAddReviewDialog(DramaProvider drama, String seriesId) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161622),
          title: const Text('Write a Review',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < _selectedRating ? Icons.star : Icons.star_border,
                      color: AppTheme.dramaGold,
                      size: 28,
                    ),
                    onPressed: () =>
                        setDialogState(() => _selectedRating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts about this series...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF222230),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_reviewController.text.trim().isNotEmpty) {
                  drama.addReview(
                      seriesId, _selectedRating, _reviewController.text);
                  _reviewController.clear();
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.storyTvPink),
              child: const Text('Submit',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);
    final series = drama.selectedSeries;

    if (series == null) {
      return Scaffold(
        backgroundColor: AppTheme.dramaBlack,
        appBar:
            AppBar(leading: BackButton(onPressed: () => drama.navigateBack())),
        body: const Center(
            child:
                Text('Drama not found', style: TextStyle(color: Colors.white))),
      );
    }

    final isInWatchlist = drama.isInWatchlist(series.id);
    final episodes = drama.currentEpisodes;
    final reviews = drama.getReviewsForSeries(series.id);

    return Scaffold(
      backgroundColor: AppTheme.dramaBlack,
      body: CustomScrollView(
        slivers: [
          // Collapsible Hero Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.dramaBlack,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => drama.navigateBack(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                  color: isInWatchlist ? AppTheme.storyTvPink : Colors.white,
                ),
                onPressed: () => drama.toggleWatchlist(series.id),
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: series.coverImageUrl.isNotEmpty
                        ? series.coverImageUrl
                        : series.posterUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          AppTheme.dramaBlack,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Series Information
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    series.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Metadata Badges (Rating, Episodes, Genres, Age)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: AppTheme.dramaGold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${series.rating}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                      const Text('•', style: TextStyle(color: Colors.white38)),
                      Text('${series.totalEpisodes} Episodes',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                      const Text('•', style: TextStyle(color: Colors.white38)),
                      Text(series.language,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white38),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(series.ageRating,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Play Button (Primary CTA)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => drama.startOrResumeSeries(series.id,
                          episodeNumber: 1),
                      icon: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 24),
                      label: const Text(
                        'Watch Episode 1 Free',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.storyTvPink,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Synopsis
                  Text(
                    series.synopsis,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),

                  // Cast
                  if (series.castMembers.isNotEmpty)
                    Text(
                      'Cast: ${series.castMembers}',
                      style: const TextStyle(
                          color: AppTheme.textDark, fontSize: 12),
                    ),
                  const SizedBox(height: 20),

                  // Tab Navigation
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.storyTvPink,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textDark,
                    tabs: [
                      Tab(text: 'Episodes (${episodes.length})'),
                      Tab(text: 'Reviews (${reviews.length})'),
                      const Tab(text: 'Details'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverToBoxAdapter(
            child: SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. EPISODES GRID
                  GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final ep = episodes[index];
                      final isLocked =
                          drama.isEpisodePaywallLocked(ep.episodeNumber, seriesId: series.id);

                      return InkWell(
                        onTap: () {
                          drama.startOrResumeSeries(series.id,
                              episodeNumber: ep.episodeNumber);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.dramaCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLocked
                                  ? Colors.white12
                                  : AppTheme.storyTvPink.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${ep.episodeNumber}',
                                    style: TextStyle(
                                      color: isLocked
                                          ? Colors.white38
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isLocked ? 'AD/VIP' : 'FREE',
                                    style: TextStyle(
                                      color: isLocked
                                          ? AppTheme.dramaGold
                                          : AppTheme.storyTvPink,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (isLocked)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(Icons.lock,
                                      color: AppTheme.dramaGold, size: 12),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // 2. REVIEWS TAB
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Viewer Reviews',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () =>
                                _showAddReviewDialog(drama, series.id),
                            icon: const Icon(Icons.rate_review,
                                color: AppTheme.storyTvPink, size: 16),
                            label: const Text('Add Review',
                                style: TextStyle(color: AppTheme.storyTvPink)),
                          ),
                        ],
                      ),
                      ...reviews.map((r) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.dramaCard,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(r.userName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    Row(
                                      children: List.generate(
                                          5,
                                          (star) => Icon(
                                                star < r.rating
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: AppTheme.dramaGold,
                                                size: 13,
                                              )),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(r.reviewText,
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          )),
                    ],
                  ),

                  // 3. DETAILS TAB
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _DetailRow(
                          label: 'Director / Studio',
                          value: series.creatorName),
                      _DetailRow(
                          label: 'Total Views',
                          value: '${series.totalViews} views'),
                      _DetailRow(label: 'Genres', value: series.genres),
                      _DetailRow(label: 'Tags', value: series.tags),
                      _DetailRow(
                          label: 'Content Advisory',
                          value:
                              '${series.ageRating} (Viewer Discretion Advised)'),
                      _DetailRow(
                          label: 'Audio Track',
                          value: '${series.language} (Original Audio)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
