import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WelcomePromoSheet extends StatelessWidget {
  final String? firstName;

  const WelcomePromoSheet({super.key, this.firstName});

  static Future<void> show(BuildContext context, {String? firstName}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (_) => WelcomePromoSheet(firstName: firstName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = firstName != null && firstName!.isNotEmpty
        ? 'Welcome back, $firstName!'
        : 'Welcome to Bill Buddy!';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting with inline icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.heroCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your finances, under control.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // Teaser card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.heroCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Exciting things are coming',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We\'re building smarter insights, shared budgets, auto-categorisation, and more. Stay tuned for early access.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // CTA
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.heroCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
