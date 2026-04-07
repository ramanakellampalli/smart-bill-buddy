import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WelcomePromoSheet extends StatelessWidget {
  final String? firstName;

  const WelcomePromoSheet({super.key, this.firstName});

  static Future<void> show(BuildContext context, {String? firstName}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => WelcomePromoSheet(firstName: firstName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    final greeting = firstName != null && firstName!.isNotEmpty
        ? 'Welcome back, $firstName!'
        : 'Welcome to Bill Buddy!';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: const BoxDecoration(
        color: AppColors.heroCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Greeting
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your finances, under control.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 28),

          // Teaser card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Exciting things are coming',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'We\'re building powerful new features — smarter insights, shared budgets, auto-categorisation, and more. Stay tuned for early access.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // CTA
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heroCard,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
