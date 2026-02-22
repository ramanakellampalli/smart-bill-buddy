import 'package:flutter/material.dart';

/// A rich gradient logo badge for a bill category.
///
/// Pass [billName] to enable automatic brand recognition for known services
/// (Netflix, Spotify, Jio, etc.) — renders a coloured badge with the brand
/// initials using the real brand colour. No network requests needed.
///
/// Falls back to the category gradient icon for unrecognised names.
/// Pass [dimmed] = true for paid/muted bills.
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

  // ── Known service brands: name-fragment → (initials, brandColor) ──────────

  static const List<(String, String, Color)> _brands = [
    // Streaming video
    ('netflix',       'N',   Color(0xFFE50914)),
    ('prime video',   'PV',  Color(0xFF00A8E1)),
    ('amazon prime',  'A+',  Color(0xFF00A8E1)),
    ('hotstar',       'HS',  Color(0xFF1A56DB)),
    ('disney+',       'D+',  Color(0xFF113CCF)),
    ('disney plus',   'D+',  Color(0xFF113CCF)),
    ('disney',        'D',   Color(0xFF113CCF)),
    ('sonyliv',       'SL',  Color(0xFF002366)),
    ('sony liv',      'SL',  Color(0xFF002366)),
    ('zee5',          'Z5',  Color(0xFF7B2D8B)),
    ('jiocinema',     'JC',  Color(0xFF003087)),
    ('jio cinema',    'JC',  Color(0xFF003087)),
    ('hulu',          'H',   Color(0xFF1CE783)),
    ('hbo',           'H',   Color(0xFF002BE7)),
    // Music
    ('spotify',       'S',   Color(0xFF1DB954)),
    ('apple music',   '♪',   Color(0xFFFC3C44)),
    ('jiosaavn',      'JS',  Color(0xFF2BC5B4)),
    ('saavn',         'JS',  Color(0xFF2BC5B4)),
    ('gaana',         'G',   Color(0xFFE72C30)),
    // YouTube
    ('youtube premium','YT', Color(0xFFFF0000)),
    ('youtube music', 'YM',  Color(0xFFFF0000)),
    ('youtube',       'YT',  Color(0xFFFF0000)),
    // Apple
    ('apple tv',      'TV',  Color(0xFF1C1C1E)),
    ('icloud',        'iC',  Color(0xFF147EFB)),
    ('apple music',   '♪',   Color(0xFFFC3C44)),
    ('apple',         'A',   Color(0xFF555555)),
    // Google
    ('google one',    'G1',  Color(0xFF4285F4)),
    ('google workspace','GW',Color(0xFF4285F4)),
    ('google',        'G',   Color(0xFF4285F4)),
    // Microsoft
    ('microsoft 365', 'M',   Color(0xFF00A4EF)),
    ('office 365',    'M',   Color(0xFF00A4EF)),
    ('microsoft',     'M',   Color(0xFF00A4EF)),
    ('onedrive',      'OD',  Color(0xFF0078D4)),
    // Cloud / tools
    ('dropbox',       'DB',  Color(0xFF0061FF)),
    ('notion',        'N',   Color(0xFF1C1C1C)),
    ('slack',         'S',   Color(0xFF4A154B)),
    ('zoom',          'Z',   Color(0xFF2D8CFF)),
    ('github',        'GH',  Color(0xFF181717)),
    ('adobe',         'Ai',  Color(0xFFFF0000)),
    ('canva',         'C',   Color(0xFF00C4CC)),
    ('figma',         'F',   Color(0xFFF24E1E)),
    ('chatgpt',       'AI',  Color(0xFF10A37F)),
    ('openai',        'AI',  Color(0xFF10A37F)),
    ('linkedin',      'in',  Color(0xFF0A66C2)),
    // Telecom India
    ('jio',           'Jio', Color(0xFF003087)),
    ('airtel',        'At',  Color(0xFFE40000)),
    ('vodafone',      'Vf',  Color(0xFFE60000)),
    ('vi ',           'Vi',  Color(0xFF582D8B)),
    ('bsnl',          'BS',  Color(0xFF003F87)),
    // Food / delivery
    ('swiggy',        'Sw',  Color(0xFFFC8019)),
    ('zomato',        'Zo',  Color(0xFFE23744)),
    // Amazon (generic — after specific prime/video entries)
    ('amazon',        'A',   Color(0xFFFF9900)),
  ];

  static (String, Color)? _brandData(String? name) {
    if (name == null || name.isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final (fragment, initials, color) in _brands) {
      if (lower.contains(fragment)) return (initials, color);
    }
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brand = _brandData(billName);
    final radius = BorderRadius.circular(size * 0.32);

    if (brand != null) {
      final (initials, color) = brand;
      final bgColor = dimmed ? const Color(0xFFE7E1D9) : color;
      final fgColor = dimmed ? const Color(0xFFA8A29E) : Colors.white;
      // Scale font: 1 char → 45%, 2 chars → 33%, 3+ chars → 25%
      final fontSize = initials.length == 1
          ? size * 0.45
          : initials.length == 2
              ? size * 0.33
              : size * 0.26;

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          boxShadow: dimmed
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: fgColor,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            letterSpacing: -0.3,
            height: 1,
          ),
        ),
      );
    }

    return _GradientIcon(category: category, size: size, dimmed: dimmed);
  }
}

// ── Gradient Icon (internal fallback) ────────────────────────────────────────

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
        return (Icons.bolt_rounded,           const Color(0xFFFBBF24), const Color(0xFFF97316));
      case 'rent':
        return (Icons.home_rounded,           const Color(0xFF818CF8), const Color(0xFF4338CA));
      case 'emi':
        return (Icons.account_balance_rounded,const Color(0xFFC084FC), const Color(0xFF7C3AED));
      case 'credit_card':
        return (Icons.credit_card_rounded,    const Color(0xFFFB7185), const Color(0xFFBE123C));
      case 'subscriptions':
        return (Icons.play_circle_rounded,    const Color(0xFF34D399), const Color(0xFF0F766E));
      case 'education':
        return (Icons.school_rounded,         const Color(0xFF38BDF8), const Color(0xFF1D4ED8));
      default:
        return (Icons.receipt_long_rounded,   const Color(0xFFA8A29E), const Color(0xFF57534E));
    }
  }
}
