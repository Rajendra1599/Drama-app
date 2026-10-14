import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/drama_provider.dart';
import '../config/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final drama = Provider.of<DramaProvider>(context);
    final isVip = drama.isVipActive;

    return Scaffold(
      backgroundColor: AppTheme.dramaBlack,
      appBar: AppBar(
        title: const Text('MY PROFILE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // User Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.dramaCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.storyTvPink.withValues(alpha: 0.2),
                    child: Text(
                      auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'G',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                auth.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'GOOGLE',
                                style: TextStyle(
                                  color: Color(0xFF64B5F6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.email,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // VIP Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isVip
                      ? [AppTheme.storyTvPink.withValues(alpha: 0.25), const Color(0xFF1E1424)]
                      : [const Color(0xFF22222E), const Color(0xFF161622)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isVip ? AppTheme.storyTvPink : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isVip ? Icons.verified : Icons.lock,
                    color: isVip ? AppTheme.dramaGold : Colors.white54,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVip ? 'StoryUp VIP Pass: ACTIVE' : 'Free Membership Tier',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isVip
                              ? 'All 50+ series & episodes fully unlocked'
                              : 'Episodes 1–5 free • Unlock 1-day pass for ₹1',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!isVip)
                    ElevatedButton(
                      onPressed: () => drama.openAutoPayDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.storyTvPink,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('₹1 Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  else
                    OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF161622),
                            title: const Text('Cancel VIP Pass?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            content: const Text('Are you sure you want to cancel your VIP Pass and revert to Free tier?', style: TextStyle(color: AppTheme.textMuted)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep VIP', style: TextStyle(color: Colors.white60)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: const Text('Cancel VIP', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await drama.cancelVipSubscription();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('VIP pass cancelled. Account reverted to Free Tier.')),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel VIP', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Navigation Links
            _ProfileMenuTile(
              icon: Icons.workspace_premium,
              title: 'VIP Membership & Billing',
              subtitle: isVip ? 'VIP active • Tap to manage or cancel' : 'Manage ₹1 trial and ₹599/mo AutoPay mandate',
              onTap: () {
                if (isVip) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF161622),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 16),
                          const Text('Active VIP Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          const Text('Plan: StoryUp VIP Pass • PhonePe AutoPay', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await drama.cancelVipSubscription();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('VIP pass has been cancelled successfully.')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              child: const Text('Cancel VIP Membership', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  drama.openAutoPayDialog();
                }
              },
            ),


            _ProfileMenuTile(
              icon: Icons.receipt_long,
              title: 'Payment Transactions',
              subtitle: 'View your digital pass purchase history',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transactions: PhonePe AutoPay Active')),
                );
              },
            ),

            _ProfileMenuTile(
              icon: Icons.description_outlined,
              title: 'Terms & Policies',
              subtitle: 'Non-refundable terms, user agreement & privacy',
              onTap: () => drama.openPoliciesDialog(),
            ),

            _ProfileMenuTile(
              icon: Icons.help_outline,
              title: 'Help & Customer Support',
              subtitle: 'WhatsApp & Email support for playback assistance',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support email: support@storyup.com')),
                );
              },
            ),

            const SizedBox(height: 10),

            _ProfileMenuTile(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Log out of this device',
              accentColor: Colors.redAccent,
              onTap: () => _confirmSignOut(context, auth),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of StoryUp?',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logoutUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'OK, Sign Out',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.dramaCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: accentColor ?? AppTheme.storyTvPink, size: 22),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        ),
      ),
    );
  }
}
