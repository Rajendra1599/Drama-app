import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drama_provider.dart';
import '../widgets/drama_card.dart';
import '../config/theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);
    final results = drama.searchResults;
    final history = drama.searchHistory;

    return Scaffold(
      backgroundColor: AppTheme.dramaBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (val) => drama.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Search title, creator, genre, cast...',
              hintStyle:
                  const TextStyle(color: AppTheme.textDark, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white70, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white70, size: 18),
                      onPressed: () {
                        _controller.clear();
                        drama.setSearchQuery('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: drama.searchQuery.trim().isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Recent Searches
                if (history.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Searches',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => drama.clearSearchHistory(),
                        child: const Text('Clear All',
                            style: TextStyle(
                                color: AppTheme.storyTvPink, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: history.map((item) {
                      return ActionChip(
                        label: Text(item,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        backgroundColor: AppTheme.dramaCard,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        onPressed: () {
                          _controller.text = item;
                          drama.setSearchQuery(item);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Trending Searches
                const Text(
                  'Trending Searches',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...['Drama', 'Romance', 'Thriller', 'Revenge', 'Action'].map(
                  (term) => Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.trending_up,
                          color: AppTheme.storyTvPink, size: 20),
                      title: Text(term,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      onTap: () {
                        _controller.text = term;
                        drama.setSearchQuery(term);
                      },
                    ),
                  ),
                ),
              ],
            )
          : results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off,
                          color: Colors.white24, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No results found for "${drama.searchQuery}"',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Try searching by story title, genre, or tags',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 9 / 16,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final series = results[index];
                    return PureStoryThumbnailCard(
                      series: series,
                      onTap: () => drama.openDramaDetail(series.id),
                    );
                  },
                ),
    );
  }
}
