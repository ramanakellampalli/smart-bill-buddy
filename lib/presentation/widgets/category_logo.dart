import 'package:flutter/material.dart';

/// A rich gradient logo badge for a bill category.
///
/// Pass [dimmed] = true for paid/muted bills — renders a flat
/// stone-toned chip with no shadow.
class CategoryLogo extends StatelessWidget {
  final String category;
  final double size;
  final bool dimmed;

  const CategoryLogo({
    super.key,
    required this.category,
    this.size = 48,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = _catData(category);
    final icon = data.$1;
    final grad1 = data.$2;
    final grad2 = data.$3;
    final radius = BorderRadius.circular(size * 0.32);

    if (dimmed) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE7E1D9),
          borderRadius: radius,
        ),
        child: Icon(icon, size: size * 0.44, color: const Color(0xFFA8A29E)),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [grad1, grad2],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: grad2.withOpacity(0.38),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.44, color: Colors.white),
    );
  }

  // Returns (icon, gradientLight, gradientDark)
  static (IconData, Color, Color) _catData(String cat) {
    switch (cat) {
      case 'utilities':
        return (
          Icons.bolt_rounded,
          const Color(0xFFFBBF24), // amber-400
          const Color(0xFFF97316), // orange-500
        );
      case 'rent':
        return (
          Icons.home_rounded,
          const Color(0xFF818CF8), // indigo-400
          const Color(0xFF4338CA), // indigo-700
        );
      case 'emi':
        return (
          Icons.account_balance_rounded,
          const Color(0xFFC084FC), // purple-400
          const Color(0xFF7C3AED), // violet-600
        );
      case 'credit_card':
        return (
          Icons.credit_card_rounded,
          const Color(0xFFFB7185), // rose-400
          const Color(0xFFBE123C), // rose-700
        );
      case 'subscriptions':
        return (
          Icons.play_circle_rounded,
          const Color(0xFF34D399), // emerald-400
          const Color(0xFF0F766E), // teal-700
        );
      case 'education':
        return (
          Icons.school_rounded,
          const Color(0xFF38BDF8), // sky-400
          const Color(0xFF1D4ED8), // blue-700
        );
      default:
        return (
          Icons.receipt_long_rounded,
          const Color(0xFFA8A29E), // stone-400
          const Color(0xFF57534E), // stone-600
        );
    }
  }
}
