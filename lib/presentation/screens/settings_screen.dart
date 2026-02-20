import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_settings_provider.dart';
import '../state/user_provider.dart';
import '../widgets/auth_guard.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _red = Color(0xFFDC2626);

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      redirectRoute: '/settings',
      child: const _SettingsScreenContent(),
    );
  }
}

class _SettingsScreenContent extends StatelessWidget {
  const _SettingsScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Settings',
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
          // Account Section
          _SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: 'Manage your profile information',
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Configure notification preferences',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.alarm_outlined,
            title: 'Reminders',
            subtitle: 'Set bill payment reminders',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Preferences Section
          _SectionHeader(title: 'Preferences'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.currency_exchange_rounded,
            title: 'Currency',
            subtitle: context.watch<AppSettingsProvider>().currency.label,
            onTap: () => _showCurrencyPicker(context),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'Choose app language',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: _themeModeLabel(context.watch<AppSettingsProvider>().themeMode),
            onTap: () => _showAppearancePicker(context),
          ),
          const SizedBox(height: 24),

          // Support Section
          _SectionHeader(title: 'Support'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get help with the app',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () => launchUrl(
              Uri.parse('https://billbuddy.app/privacy'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out Section
          _SectionHeader(title: 'Session'),
          const SizedBox(height: 8),
          _SignOutTile(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Components ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
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
      ),
    );
  }
}

class _SignOutTile extends StatelessWidget {
  const _SignOutTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: () => _showSignOutDialog(context),
        splashColor: _red.withOpacity(0.06),
        highlightColor: _red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: _red, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _red,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sign out of your account',
                      style: TextStyle(
                        fontSize: 13,
                        color: _red,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _red,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Currency picker ───────────────────────────────────────────────────────────

String _themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System default';
  }
}

void _showCurrencyPicker(BuildContext context) {
  final settings = context.read<AppSettingsProvider>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CurrencyPickerSheet(settings: settings),
  );
}

class _CurrencyPickerSheet extends StatelessWidget {
  final AppSettingsProvider settings;

  const _CurrencyPickerSheet({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Currency',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(kCurrencies.length, (i) {
            final c = kCurrencies[i];
            final selected = settings.currencyIndex == i;
            return InkWell(
              onTap: () {
                settings.setCurrency(i);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? _primary.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(color: _primary.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? _primary.withOpacity(0.15)
                            : _border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          c.symbol,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: selected ? _primary : _textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selected ? _primary : _textPrimary,
                            ),
                          ),
                          Text(
                            c.code,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Appearance picker ─────────────────────────────────────────────────────────

void _showAppearancePicker(BuildContext context) {
  final settings = context.read<AppSettingsProvider>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppearancePickerSheet(settings: settings),
  );
}

class _AppearancePickerSheet extends StatelessWidget {
  final AppSettingsProvider settings;

  const _AppearancePickerSheet({required this.settings});

  @override
  Widget build(BuildContext context) {
    final options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System default',
          'Follow device setting'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light',
          'Always use light theme'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark',
          'Always use dark theme'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final (mode, icon, label, desc) = opt;
            final selected = settings.themeMode == mode;
            return InkWell(
              onTap: () {
                settings.setThemeMode(mode);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? _primary.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(color: _primary.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? _primary.withOpacity(0.15)
                            : _border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: selected ? _primary : _textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selected ? _primary : _textPrimary,
                            ),
                          ),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Sign out dialog ───────────────────────────────────────────────────────────

void _showSignOutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Sign Out',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
      content: const Text(
        'Are you sure you want to sign out? You can always sign back in with your email and password.',
        style: TextStyle(
          fontSize: 14,
          color: _textSecondary,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: _textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await FirebaseAuth.instance.signOut();
              // UserProvider will automatically handle state changes
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _red,
                    content: const Text('Failed to sign out. Please try again.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Sign Out',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
