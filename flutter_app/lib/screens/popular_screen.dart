import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drama_provider.dart';
import '../services/payment_service.dart';
import '../config/theme.dart';

class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      appBar: AppBar(
        title: const Text(
          'VIP MEMBERSHIP',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Compact VIP Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.storyTvPink.withValues(alpha: 0.2),
                      const Color(0xFF161622),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.storyTvPink.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.storyTvPink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium, color: AppTheme.dramaGold, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'STORYUP VIP PASS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Unlock all episodes & premium short series',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Plan Card (₹1 Trial + ₹599/mo AutoPay)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.storyTvPink, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '1-Day VIP Trial Pass',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.storyTvPink,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SPECIAL OFFER',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Price Breakdown
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text(
                          '₹1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '₹599',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'for 24 hours, then ₹599/month',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),

                    // Moderate Benefit Rows
                    _benefitRow('24-Hour full VIP access to every single episode'),
                    _benefitRow('AutoPay mandate sets up automatically at ₹599/month'),
                    _benefitRow('Full HD streaming with zero ads & instant playback'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Compact UPI Selector
              const Text(
                'Select UPI App for AutoPay:',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _UpiButton(
                      title: 'PhonePe',
                      icon: Icons.account_balance_wallet,
                      selected: drama.selectedUpiTarget == UpiAppTarget.phonePe,
                      onTap: () => drama.setSelectedUpiTarget(UpiAppTarget.phonePe),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UpiButton(
                      title: 'Google Pay',
                      icon: Icons.payment,
                      selected: drama.selectedUpiTarget == UpiAppTarget.gpay,
                      onTap: () => drama.setSelectedUpiTarget(UpiAppTarget.gpay),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UpiButton(
                      title: 'Paytm / UPI',
                      icon: Icons.qr_code,
                      selected: drama.selectedUpiTarget == UpiAppTarget.paytm,
                      onTap: () => drama.setSelectedUpiTarget(UpiAppTarget.paytm),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Pay CTA Button
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => drama.initiatePhonePePayment(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.storyTvPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 4,
                  ),
                  child: const Text(
                    'PAY ₹1 & START 1-DAY TRIAL ➔',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 5. Strict Non-Refundable & AutoPay Notice
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: const [
                    Text(
                      '⚠️ STRICT NON-REFUNDABLE POLICY: Once any transaction is processed, it is strictly non-refundable.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFFB74D), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Paying ₹1 activates a 1-day (24h) trial and sets up an automated monthly AutoPay mandate of ₹599 on your phone. You can cancel recurring mandate anytime in your UPI app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _benefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.storyTvPink, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _UpiButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _UpiButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.storyTvPink.withValues(alpha: 0.15) : const Color(0xFF14141C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.storyTvPink : Colors.white12,
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppTheme.storyTvPink : Colors.white70, size: 18),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
