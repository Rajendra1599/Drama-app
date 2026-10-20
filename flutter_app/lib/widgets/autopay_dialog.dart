import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/drama_provider.dart';

/// StoryUp OTT - VIP Subscription Dialog (Under Working)
/// Replaces the old payment paywall with a clear "Under Working" notification
/// and directs users to watch all episodes unlocked with Google AdMob ads.
class PaymentAutopayDialog extends StatelessWidget {
  const PaymentAutopayDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final dramaProvider = Provider.of<DramaProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.dramaGold.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row with "UNDER WORKING" badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.construction, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'UNDER DEVELOPMENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => dramaProvider.closeAutoPayDialog(),
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title & Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.dramaGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: AppTheme.dramaGold,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Payment & VIP is Under Development',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Payment gateway and VIP subscriptions are currently under development. All microdrama episodes are unlocked free with Google AdMob ads!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Free with Ad Notification Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'All Episodes Unlocked Free',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You do not need to pay! Every episode is unlocked and free to watch with short Google AdMob ads.',
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CTA Button to dismiss and continue watching
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => dramaProvider.closeAutoPayDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.storyTvPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                  ),
                  child: const Text(
                    'WATCH FREE WITH ADS ➔',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Google AdMob Test Mode Active',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
