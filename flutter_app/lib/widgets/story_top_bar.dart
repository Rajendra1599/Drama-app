import 'package:flutter/material.dart';
import '../config/theme.dart';

class StoryTopBar extends StatelessWidget {
  final VoidCallback onSearchClick;
  final VoidCallback onRenewPlanClick;

  const StoryTopBar({
    super.key,
    required this.onSearchClick,
    required this.onRenewPlanClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // STORY UP Brand Logo with Antenna TV Icon
              Row(
                children: [
                  CustomPaint(
                    size: const Size(26, 26),
                    painter: AntennaTvLogoPainter(),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'STORY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'UP',
                          style: TextStyle(
                            color: AppTheme.storyTvPink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Right Section: Renew Plan VIP button & Search Icon
              Row(
                children: [
                  // Renew Plan Pill Button
                  InkWell(
                    onTap: onRenewPlanClick,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.storyTvPink, Color(0xFFFF5EA8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.storyTvPink.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'VIP PASS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search Icon Button
                  IconButton(
                    onPressed: onSearchClick,
                    icon: const Icon(Icons.search, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AntennaTvLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.storyTvPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = AppTheme.storyTvPink
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Draw V antennas
    canvas.drawLine(Offset(w * 0.5, h * 0.35), Offset(w * 0.2, h * 0.05), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.35), Offset(w * 0.8, h * 0.05), paint);

    // Antenna tips
    canvas.drawCircle(Offset(w * 0.2, h * 0.05), 1.8, fillPaint);
    canvas.drawCircle(Offset(w * 0.8, h * 0.05), 1.8, fillPaint);

    // TV Body (Rounded rectangle)
    final tvRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.58),
      const Radius.circular(4),
    );
    canvas.drawRRect(tvRect, paint);

    // Screen line / play icon inside
    final path = Path()
      ..moveTo(w * 0.42, h * 0.5)
      ..lineTo(w * 0.62, h * 0.64)
      ..lineTo(w * 0.42, h * 0.78)
      ..close();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
