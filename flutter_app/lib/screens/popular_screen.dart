import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drama_provider.dart';
import '../models/user_role.dart';
import '../config/theme.dart';

/// StoryUp OTT - VIP & Payment (Under Development) Screen
class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      appBar: AppBar(
        title: const Text(
          'VIP & PAYMENTS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Construction / VIP Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade600, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade600.withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.construction_rounded,
                      color: Colors.amber.shade400,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade500,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'UNDER DEVELOPMENT',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'Payment & VIP Under Development',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'All payment gateways, UPI AutoPay, and VIP subscriptions are currently under development. You do not need to make any payment!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Feature Highlights Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161622),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.tv_rounded,
                        title: 'All Series & Dramas Available',
                        subtitle: 'Episodes 1 & 2 are 100% free with instant playback.',
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      _buildInfoRow(
                        icon: Icons.ad_units_rounded,
                        title: 'Unlock Every 2 Episodes with Ads',
                        subtitle: 'Watch a quick Google AdMob ad to unlock the next 2 episodes.',
                      ),
                      const Divider(color: Colors.white10, height: 20),
                      _buildInfoRow(
                        icon: Icons.storefront_rounded,
                        title: 'Google Play Store Release',
                        subtitle: 'Official subscriptions will go live once published to Play Store.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Navigation Button to Home
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => drama.navigateTo(AppScreen.home),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.storyTvPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'START WATCHING DRAMAS ➔',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.storyTvPink.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.storyTvPink, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
