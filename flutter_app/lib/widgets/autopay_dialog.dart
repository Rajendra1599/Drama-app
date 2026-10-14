import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/drama_provider.dart';
import '../services/payment_service.dart';

class PaymentAutopayDialog extends StatelessWidget {
  const PaymentAutopayDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final dramaProvider = Provider.of<DramaProvider>(context);
    final plan = dramaProvider.selectedAutoPayPlan;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: const Color(0xFF161620),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.storyTvPink.withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.storyTvPink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VIP ACCESS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => dramaProvider.closeAutoPayDialog(),
                    icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              const Text(
                'Unlock All Episodes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Enjoy uninterrupted HD vertical streaming',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),

              // Price Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          '₹1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${plan.recurringPriceInr.toInt()}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '99% OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '1-Day Trial • AutoPay Mandate ₹599/mo',
                      style: TextStyle(color: AppTheme.dramaGold, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // UPI App Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _UpiAppPill(
                    title: 'Auto',
                    target: UpiAppTarget.autoDetect,
                    selected: dramaProvider.selectedUpiTarget == UpiAppTarget.autoDetect,
                    onSelect: () => dramaProvider.setSelectedUpiTarget(UpiAppTarget.autoDetect),
                  ),
                  _UpiAppPill(
                    title: 'PhonePe',
                    target: UpiAppTarget.phonePe,
                    selected: dramaProvider.selectedUpiTarget == UpiAppTarget.phonePe,
                    onSelect: () => dramaProvider.setSelectedUpiTarget(UpiAppTarget.phonePe),
                  ),
                  _UpiAppPill(
                    title: 'GPay',
                    target: UpiAppTarget.gpay,
                    selected: dramaProvider.selectedUpiTarget == UpiAppTarget.gpay,
                    onSelect: () => dramaProvider.setSelectedUpiTarget(UpiAppTarget.gpay),
                  ),
                  _UpiAppPill(
                    title: 'Paytm',
                    target: UpiAppTarget.paytm,
                    selected: dramaProvider.selectedUpiTarget == UpiAppTarget.paytm,
                    onSelect: () => dramaProvider.setSelectedUpiTarget(UpiAppTarget.paytm),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Pay Now CTA Button
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: () => dramaProvider.initiatePhonePePayment(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.storyTvPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                  ),
                  child: const Text(
                    'PAY ₹1 & START STREAMING ➔',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Disclaimer
              const Text(
                'Strictly Non-Refundable • Sets up recurring ₹599/mo AutoPay. Cancel anytime in your UPI app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFFFB74D), fontSize: 9, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpiAppPill extends StatelessWidget {
  final String title;
  final UpiAppTarget target;
  final bool selected;
  final VoidCallback onSelect;

  const _UpiAppPill({
    required this.title,
    required this.target,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.storyTvPink.withValues(alpha: 0.25) : const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppTheme.storyTvPink : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
