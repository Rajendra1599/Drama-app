import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../config/theme.dart';

class StoryBottomNav extends StatelessWidget {
  final AppScreen currentScreen;
  final ValueChanged<AppScreen> onNavigate;

  const StoryBottomNav({
    super.key,
    required this.currentScreen,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppScreen.home, 'Home', Icons.home),
      (AppScreen.explore, 'Explore', Icons.play_circle_outline),
      (AppScreen.popular, 'Premium', Icons.workspace_premium),
      (AppScreen.library, 'My List', Icons.bookmark_border),
      (AppScreen.profile, 'Profile', Icons.person_outline),
    ];

    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isSelected = currentScreen == item.$1;
              return Expanded(
                child: InkWell(
                  onTap: () => onNavigate(item.$1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$3,
                        color: isSelected ? AppTheme.storyTvPink : const Color(0xFF888888),
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
