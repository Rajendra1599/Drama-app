import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drama_series.dart';
import '../providers/drama_provider.dart';
import '../widgets/drama_card.dart';
import '../config/theme.dart';

class SeeAllDramasSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<DramaSeries> stories;

  const SeeAllDramasSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stories,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<DramaSeries> stories,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SeeAllDramasSheet(
        title: title,
        subtitle: subtitle,
        stories: stories,
      ),
    );
  }

  @override
  State<SeeAllDramasSheet> createState() => _SeeAllDramasSheetState();
}

class _SeeAllDramasSheetState extends State<SeeAllDramasSheet> {
  String _searchQuery = '';
  String _selectedGenre = 'All';

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);

    // Extract unique genres
    final allGenres = <String>{'All'};
    for (final s in widget.stories) {
      if (s.genres.isNotEmpty) {
        for (final g in s.genres.split(',')) {
          if (g.trim().isNotEmpty) allGenres.add(g.trim());
        }
      }
    }

    final filteredStories = widget.stories.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.synopsis.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGenre = _selectedGenre == 'All' ||
          s.genres.toLowerCase().contains(_selectedGenre.toLowerCase());
      return matchesSearch && matchesGenre;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Title, Subtitle, Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filteredStories.length} dramas available • ${widget.subtitle}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Search inside category
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.title}...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          // Genre filter chips
          if (allGenres.length > 2)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: allGenres.map((genre) {
                  final isSelected = _selectedGenre == genre;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        genre,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.storyTvPink,
                      backgroundColor: const Color(0xFF1C1C28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (_) => setState(() => _selectedGenre = genre),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),

          // Drama Grid
          Expanded(
            child: filteredStories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.search_off_rounded, color: Colors.white24, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'No dramas match your search',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredStories.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 9 / 15.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 16,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredStories[index];
                      return PureStoryThumbnailCard(
                        series: item,
                        onTap: () {
                          Navigator.pop(context);
                          drama.startOrResumeSeries(item.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
