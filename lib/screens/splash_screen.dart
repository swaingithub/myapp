import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'onboarding_screen.dart';
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            onboardingSeen ? const AuthWrapper() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ripple Effect Logo
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer Ripple
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.1),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(2.5, 2.5),
                        duration: 2.seconds)
                    .fadeOut(duration: 2.seconds),

                // Inner Ripple
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.2),
                  ),
                )
                    .animate(
                        delay: 500.ms,
                        onPlay: (controller) => controller.repeat())
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.8, 1.8),
                        duration: 2.seconds)
                    .fadeOut(duration: 2.seconds),

                // Main Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
              ],
            ),

            const SizedBox(height: 60),

            // Text
            Text(
              'Sanchar',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 16),

            Text(
              'Connecting You...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
                letterSpacing: 1.0,
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
