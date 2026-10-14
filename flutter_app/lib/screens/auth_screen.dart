import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../widgets/policies_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  void _handleGoogleSignIn(AuthProvider auth) async {
    final success = await auth.signInWithGoogle();

    if (!success && mounted) {
      if (auth.errorMessage != null && auth.errorMessage != 'Sign-in cancelled') {
        // If native Google Play Services failed (e.g. emulator without Play Services or ApiException),
        // offer manual email sign in so user can sign in with their own account
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            content: Text('${auth.errorMessage} - You can also enter your email directly.'),
            duration: const Duration(seconds: 4),
          ),
        );
        _showEmailSignInDialog(auth);
      }
    }
  }

  void _showEmailSignInDialog(AuthProvider auth) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_circle, color: AppTheme.storyTvPink),
            SizedBox(width: 8),
            Text('Sign In with Email', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google account details to sign in:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. yourname@gmail.com',
                hintStyle: const TextStyle(color: Colors.white38),
                labelText: 'Google Email Address',
                labelStyle: const TextStyle(color: AppTheme.storyTvPink),
                filled: true,
                fillColor: const Color(0xFF121218),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Your Name',
                hintStyle: const TextStyle(color: Colors.white38),
                labelText: 'Your Full Name',
                labelStyle: const TextStyle(color: AppTheme.storyTvPink),
                filled: true,
                fillColor: const Color(0xFF121218),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim().toLowerCase();
              final name = nameController.text.trim();
              if (!email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address')),
                );
                return;
              }
              Navigator.pop(ctx);
              await auth.signInWithGoogle(
                customEmail: email,
                customName: name.isNotEmpty ? name : email.split('@')[0],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.storyTvPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.dramaBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.tv, color: Colors.white, size: 36),
                    SizedBox(width: 10),
                    Text(
                      'STORY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'UP',
                      style: TextStyle(
                        color: AppTheme.storyTvPink,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'INDIA’S FASTEST OTT MICRODRAMA',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Welcome title
                      const Text(
                        'Sign In to StoryUp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Unlock unlimited 9:16 vertical micro-dramas in HD',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Value Highlights
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: const [
                            _BenefitRow(icon: Icons.flash_on, label: 'Instant 1-Minute Episodes'),
                            SizedBox(height: 8),
                            _BenefitRow(icon: Icons.lock_open, label: 'Episodes 1 to 5 Free on All Stories'),
                            SizedBox(height: 8),
                            _BenefitRow(icon: Icons.card_membership, label: '24-Hour VIP Trial for ₹1 (AutoPay ₹599/mo)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),

                      // ========================================================
                      // OFFICIAL "CONTINUE WITH GOOGLE" BUTTON
                      // ========================================================
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => _handleGoogleSignIn(auth),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F1F1F),
                              elevation: 4,
                              shadowColor: Colors.black.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppTheme.storyTvPink,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Official Google 'G' Logo
                                      Image.network(
                                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                                        width: 20,
                                        height: 20,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.account_circle, color: Color(0xFF4285F4), size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1F1F1F),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _showEmailSignInDialog(auth),
                          icon: const Icon(Icons.mail_outline, color: Colors.white70, size: 16),
                          label: const Text(
                            'Or sign in with Google Email directly',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Terms & Non-Refundable Notice
                InkWell(
                  onTap: () => PoliciesDialog.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: AppTheme.textDark, fontSize: 11, height: 1.4),
                        children: [
                          TextSpan(text: 'By continuing with Google, you agree to StoryUp’s '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                          ),
                          TextSpan(text: ' and acknowledge that all passes are subject to our '),
                          TextSpan(
                            text: 'Strict Non-Refundable Policy',
                            style: TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '.'),
                        ],
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
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.storyTvPink, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

