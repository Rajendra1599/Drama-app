import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../providers/drama_provider.dart';
import '../services/payment_service.dart';

class PaymentVerificationDialog extends StatelessWidget {
  final VoidCallback? onCancel;

  const PaymentVerificationDialog({super.key, this.onCancel});

  void _handleCancel(DramaProvider drama) {
    if (onCancel != null) {
      onCancel!();
    } else {
      drama.cancelPhonePePayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final drama = Provider.of<DramaProvider>(context);
    final isVerifying = drama.isPaymentVerifying;
    final errorMsg = drama.paymentErrorMessage;

    return PopScope(
      canPop: !isVerifying,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _handleCancel(drama);
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.storyTvPink.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5F259F).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment, color: Color(0xFF9D65E5), size: 13),
                          SizedBox(width: 5),
                          Text(
                            'PHONEPE AUTOPAY',
                            style: TextStyle(
                              color: Color(0xFFD3B7FF),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: isVerifying ? null : () => _handleCancel(drama),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Icon or Spinner
                if (isVerifying)
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: AppTheme.storyTvPink,
                      strokeWidth: 3.5,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF5F259F).withValues(alpha: 0.2),
                      border: Border.all(color: const Color(0xFF9D65E5).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF9D65E5), size: 32),
                  ),
                const SizedBox(height: 14),

                Text(
                  isVerifying ? 'Confirming with PhonePe...' : 'Redirected to PhonePe',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                const Text(
                  'Approve the ₹1 trial mandate in PhonePe.\nOnce approved, tap below to activate your ₹599/mo AutoPay and unlock all episodes instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),

                // Mandate Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trial Charge', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          SizedBox(height: 2),
                          Text('₹1.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('AutoPay Mandate', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          SizedBox(height: 2),
                          Text('₹599/month', style: TextStyle(color: AppTheme.dramaGold, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Web QR Code or Android Re-Open Button
                if (kIsWeb) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5F259F).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent('upi://pay?pa=microdrama.autopay@ybl&pn=StoryUp%20VIP&am=1.00&cu=INR&tr=${drama.activePaymentTransactionId ?? 'MD_AUTOPAY'}')}',
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const SizedBox(
                            width: 140,
                            height: 140,
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF5F259F), strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => const SizedBox(
                            width: 140,
                            height: 140,
                            child: Center(
                                child: Icon(Icons.qr_code,
                                    size: 60, color: Colors.black45)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Scan with PhonePe / GPay on Phone',
                          style: TextStyle(
                            color: Color(0xFF5F259F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF9D65E5)),
                      label: const Text('Re-open PhonePe App', style: TextStyle(color: Color(0xFFD3B7FF), fontSize: 11)),
                      onPressed: () => PaymentService.launchUpiAutoPay(
                        userId: 'user_demo_101',
                        plan: drama.selectedAutoPayPlan,
                        target: UpiAppTarget.phonePe,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF5F259F)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],

                // Error Message if any
                if (errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMsg,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Primary Action Button: Confirm & Start Streaming (No reference number needed!)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            await drama.verifyAndCompletePayment();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.storyTvPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'CONFIRM & START STREAMING ➔',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // Secondary Action Button: Cancel (Didn't Pay)
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton(
                    onPressed: isVerifying ? null : () => _handleCancel(drama),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel (I Didn\'t Pay)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Security Note
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.successGreen, size: 13),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'NPCI Certified • 256-Bit Bank-Grade AutoPay',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


