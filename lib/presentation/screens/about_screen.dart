import 'package:flutter/material.dart';
import '../widgets/auth_guard.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);

// ── Screen ────────────────────────────────────────────────────────────────────

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      redirectRoute: '/about',
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text(
            'About',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // App Icon and Name
            _AppInfoCard(
              icon: Icons.receipt_long_rounded,
              title: 'Smart Bill Reminder',
              subtitle: 'Version $_appVersion',
              description: 'Your smart companion for managing bills and payments',
            ),
            const SizedBox(height: 24),

            // Features
            _SectionCard(
              title: 'Features',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FeatureItem(
                    icon: Icons.notifications_active_rounded,
                    title: 'Smart Reminders',
                    description: 'Never miss a bill payment with intelligent notifications',
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.analytics_rounded,
                    title: 'Analytics Dashboard',
                    description: 'Track your spending and payment patterns',
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.security_rounded,
                    title: 'Secure & Private',
                    description: 'Your data is encrypted and stored securely',
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.sync_rounded,
                    title: 'Real-time Sync',
                    description: 'Access your bills from any device',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Developer Info
            _SectionCard(
              title: 'Developer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoItem(
                    icon: Icons.code_rounded,
                    label: 'Built with',
                    value: 'Flutter & Firebase',
                  ),
                  const SizedBox(height: 12),
                  _InfoItem(
                    icon: Icons.favorite_rounded,
                    label: 'Made with',
                    value: '❤️ in India',
                  ),
                  const SizedBox(height: 12),
                  _InfoItem(
                    icon: Icons.email_rounded,
                    label: 'Contact',
                    value: 'support@smartbill.app',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Legal
            _SectionCard(
              title: 'Legal',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LinkItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _LinkItem(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    subtitle: 'Rules and guidelines',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _LinkItem(
                    icon: Icons.code_outlined,
                    title: 'Open Source',
                    subtitle: 'View source code',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Version Details
            _SectionCard(
              title: 'Version Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Version',
                    value: _appVersion,
                  ),
                  const SizedBox(height: 12),
                  _InfoItem(
                    icon: Icons.build_rounded,
                    label: 'Build',
                    value: _buildNumber,
                  ),
                  const SizedBox(height: 12),
                  _InfoItem(
                    icon: Icons.apps_rounded,
                    label: 'Package',
                    value: 'com.smartbill.reminder',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Components ─────────────────────────────────────────────────────────────────

class _AppInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  const _AppInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withOpacity(0.20)),
            ),
            child: Icon(icon, color: _primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _primary.withOpacity(0.06),
      highlightColor: _primary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: _textTertiary, size: 18),
            const SizedBox(width: 12),
            Text(
              '$label: ',
              style: const TextStyle(
                fontSize: 14,
                color: _textTertiary,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap != null ? _primary : _textSecondary,
                  fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _primary.withOpacity(0.06),
      highlightColor: _primary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: _textTertiary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
