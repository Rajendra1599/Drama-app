import 'package:flutter/material.dart';
import '../config/theme.dart';

class PoliciesDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback? onDismiss;
  final bool isFirstEntry;

  const PoliciesDialog({
    super.key,
    required this.onAccept,
    this.onDismiss,
    this.isFirstEntry = false,
  });

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => PoliciesDialog(
        onAccept: () => Navigator.of(ctx).pop(),
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.gavel, color: AppTheme.storyTvPink, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Terms & User Policies',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (!isFirstEntry && onDismiss != null)
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Strict Non-Refundable Policy Header
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF261814),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFF9800), width: 1.2)),
                      ),
                      child: Text(
                        '⚠️ STRICT NON-REFUNDABLE POLICY:\nOnce any transaction or payment is completed on StoryUp, it is strictly non-refundable under all circumstances. No refunds, returns, or chargeback claims will be accepted after order processing.',
                        style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                    ),
                    SizedBox(height: 14),

                    Text(
                      '1. 1-Day Trial for ₹1',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Users are offered a special 1-Day (24-Hour) VIP Trial Pass for an initial charge of ₹1. This unlocks unlimited playback of all episodes across every published microdrama for 24 continuous hours from the timestamp of activation.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                    SizedBox(height: 14),

                    Text(
                      '2. Automatic AutoPay Mandate Setup (₹599/month)',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upon completing the ₹1 trial payment via UPI (PhonePe, GPay, Paytm) or card, an automatic recurring AutoPay mandate is automatically established on your phone and bank account. After the 24-hour trial period lapses, your subscription will automatically renew and ₹599 will be deducted every month from your linked account until you explicitly cancel the mandate.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                    SizedBox(height: 14),

                    Text(
                      '3. Managing & Cancelling AutoPay',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You retain full authority to cancel the recurring AutoPay mandate at any time directly through your UPI application (PhonePe / GPay / Paytm / Banking App) under Autopay / Mandates section. If cancelled, access continues until the end of the paid billing cycle, after which no further monthly deductions occur.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                    SizedBox(height: 14),

                    Text(
                      '4. Intellectual Property & Digital Usage',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All vertical videos, subtitles, and original audio are the exclusive proprietary content of StoryUp. Screen recording, downloading, ripping, or unauthorized redistribution is strictly prohibited and subject to legal prosecution.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Accept Button
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.storyTvPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isFirstEntry ? 'I AGREE & CONTINUE ➔' : 'CLOSE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
