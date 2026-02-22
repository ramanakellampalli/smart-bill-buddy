import 'package:flutter/material.dart';

/// A rich gradient logo badge for a bill category.
///
/// Pass [billName] to enable automatic brand-logo lookup for known services
/// (Netflix, Spotify, Jio, etc.) via the Clearbit Logo API.
/// Falls back to the category gradient icon if the name is unrecognised or
/// the network request fails.
///
/// Pass [dimmed] = true for paid/muted bills — renders a flat
/// stone-toned chip with no shadow (or a faded logo for recognised brands).
class CategoryLogo extends StatelessWidget {
  final String category;
  final double size;
  final bool dimmed;
  final String? billName;

  const CategoryLogo({
    super.key,
    required this.category,
    this.size = 48,
    this.dimmed = false,
    this.billName,
  });

  // ── Service name → Clearbit domain ────────────────────────────────────────

  static const Map<String, String> _serviceMap = {
    // Streaming video
    'netflix': 'netflix.com',
    'prime video': 'primevideo.com',
    'amazon prime': 'primevideo.com',
    'hotstar': 'hotstar.com',
    'disney+': 'disneyplus.com',
    'disney plus': 'disneyplus.com',
    'disney': 'disneyplus.com',
    'sonyliv': 'sonyliv.com',
    'sony liv': 'sonyliv.com',
    'zee5': 'zee5.com',
    'jio cinema': 'jiocinema.com',
    'jiocinema': 'jiocinema.com',
    'hulu': 'hulu.com',
    'max': 'max.com',
    'hbo': 'hbo.com',
    'paramount': 'paramountplus.com',
    'apple tv': 'apple.com',
    // Music
    'spotify': 'spotify.com',
    'apple music': 'apple.com',
    'youtube premium': 'youtube.com',
    'youtube music': 'youtube.com',
    'youtube': 'youtube.com',
    'gaana': 'gaana.com',
    'wynk': 'airtel.in',
    'jiosaavn': 'jiosaavn.com',
    'saavn': 'jiosaavn.com',
    // Cloud / storage
    'icloud': 'apple.com',
    'google one': 'google.com',
    'dropbox': 'dropbox.com',
    'onedrive': 'microsoft.com',
    // Productivity / SaaS
    'notion': 'notion.so',
    'slack': 'slack.com',
    'zoom': 'zoom.us',
    'github': 'github.com',
    'adobe': 'adobe.com',
    'canva': 'canva.com',
    'figma': 'figma.com',
    'chatgpt': 'openai.com',
    'openai': 'openai.com',
    'microsoft 365': 'microsoft.com',
    'office 365': 'microsoft.com',
    'microsoft': 'microsoft.com',
    'google workspace': 'google.com',
    'linkedin': 'linkedin.com',
    // Telecom (India)
    'jio': 'jio.com',
    'airtel': 'airtel.in',
    'vodafone': 'vodafone.com',
    'vi ': 'myvi.in',
    'bsnl': 'bsnl.co.in',
    // Food / delivery
    'swiggy': 'swiggy.com',
    'zomato': 'zomato.com',
    // Finance / insurance
    'amazon': 'amazon.com',
    'apple': 'apple.com',
    'google': 'google.com',
  };

  static String? _logoUrl(String? name) {
    if (name == null || name.isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final entry in _serviceMap.entries) {
      if (lower.contains(entry.key)) {
        // Google S2 favicon service — free, reliable, no CORS issues.
        return 'https://www.google.com/s2/favicons?domain=${entry.value}&sz=128';
      }
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final logoUrl = _logoUrl(billName);
    final radius = BorderRadius.circular(size * 0.32);

    if (logoUrl != null) {
      return Opacity(
        opacity: dimmed ? 0.45 : 1.0,
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            width: size,
            height: size,
            color: Colors.white,
            child: Image.network(
              logoUrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              // If logo fails to load, fall back to the category gradient icon.
              errorBuilder: (_, __, ___) => _GradientIcon(
                category: category,
                size: size,
                dimmed: dimmed,
              ),
            ),
          ),
        ),
      );
    }

    return _GradientIcon(category: category, size: size, dimmed: dimmed);
  }
}

// ── Gradient Icon (internal) ──────────────────────────────────────────────────

class _GradientIcon extends StatelessWidget {
  final String category;
  final double size;
  final bool dimmed;

  const _GradientIcon({
    required this.category,
    required this.size,
    required this.dimmed,
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

  static (IconData, Color, Color) _catData(String cat) {
    switch (cat) {
      case 'utilities':
        return (
          Icons.bolt_rounded,
          const Color(0xFFFBBF24),
          const Color(0xFFF97316),
        );
      case 'rent':
        return (
          Icons.home_rounded,
          const Color(0xFF818CF8),
          const Color(0xFF4338CA),
        );
      case 'emi':
        return (
          Icons.account_balance_rounded,
          const Color(0xFFC084FC),
          const Color(0xFF7C3AED),
        );
      case 'credit_card':
        return (
          Icons.credit_card_rounded,
          const Color(0xFFFB7185),
          const Color(0xFFBE123C),
        );
      case 'subscriptions':
        return (
          Icons.play_circle_rounded,
          const Color(0xFF34D399),
          const Color(0xFF0F766E),
        );
      case 'education':
        return (
          Icons.school_rounded,
          const Color(0xFF38BDF8),
          const Color(0xFF1D4ED8),
        );
      default:
        return (
          Icons.receipt_long_rounded,
          const Color(0xFFA8A29E),
          const Color(0xFF57534E),
        );
    }
  }
}
