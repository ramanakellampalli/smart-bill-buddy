import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/user_provider.dart';
import '../../data/models/user_model.dart';
import '../state/bills_provider.dart';
import '../widgets/auth_guard.dart';
import 'insights_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _surface2 = Color(0xFFFDF5ED);
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8B5CF6);

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      redirectRoute: '/profile',
      child: const _ProfileScreenContent(),
    );
  }
}

class _ProfileScreenContent extends StatefulWidget {
  const _ProfileScreenContent({super.key});

  @override
  State<_ProfileScreenContent> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreenContent> {
  bool _isEditing = false;
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _startEditing(UserProfile profile) {
    setState(() {
      _isEditing = true;
      _displayNameController.text = profile.displayName ?? '';
    });
  }

  void _saveProfile() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.updateDisplayName(_displayNameController.text.trim());
    setState(() => _isEditing = false);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
    _displayNameController.clear();
  }

  void _showPhotoOptions(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final hasPhoto = context.read<UserProvider>().profile?.photoUrl != null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PhotoOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera, uid);
              },
            ),
            const SizedBox(height: 8),
            _PhotoOption(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Library',
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery, uid);
              },
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              _PhotoOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove Photo',
                color: _red,
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto(uid);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source, String uid) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$uid/avatar.jpg');
      final bytes = await picked.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      await context.read<UserProvider>().updatePhotoUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _red,
            content: Text('Upload failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto(String uid) async {
    try {
      await FirebaseStorage.instance
          .ref()
          .child('users/$uid/avatar.jpg')
          .delete();
    } catch (_) {
      // If delete fails (file may not exist), still clear the URL
    }
    if (mounted) {
      await context.read<UserProvider>().updatePhotoUrl(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final billsProvider = context.watch<BillsProvider>();
    
    if (user.isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text('Profile', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        ),
        body: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final profile = user.profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          title: const Text('Profile', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        ),
        body: const Center(
          child: Text('Profile data not available', style: TextStyle(color: _textSecondary)),
        ),
      );
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: profile.currency, decimalDigits: 0);
    final memberSince = profile.createdAt != null 
        ? DateFormat('MMMM yyyy').format(profile.createdAt!)
        : 'Unknown';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Profile' : 'Profile', 
                   style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _textSecondary, size: 22),
              onPressed: () => _startEditing(profile),
              tooltip: 'Edit Profile',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.close_outlined, color: _textSecondary, size: 22),
              onPressed: _cancelEditing,
              tooltip: 'Cancel',
            ),
            IconButton(
              icon: const Icon(Icons.check_outlined, color: _primary, size: 22),
              onPressed: _saveProfile,
              tooltip: 'Save',
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            profile: profile,
            isEditing: _isEditing,
            displayNameController: _displayNameController,
            onPhotoTap: () => _showPhotoOptions(context),
          ),
          const SizedBox(height: 24),

          _StatsSection(
            profile: profile,
            billsProvider: billsProvider,
            currency: currency,
          ),
          const SizedBox(height: 24),

          // ── Insights shortcut ────────────────────────────────────────────
          _InsightsShortcut(),
          const SizedBox(height: 24),

          _PreferencesSection(profile: profile),
          const SizedBox(height: 24),

          _AccountSection(
            profile: profile,
            memberSince: memberSince,
          ),
          const SizedBox(height: 24),

          _DangerSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Profile Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool isEditing;
  final TextEditingController displayNameController;
  final VoidCallback onPhotoTap;

  const _ProfileHeader({
    required this.profile,
    required this.isEditing,
    required this.displayNameController,
    required this.onPhotoTap,
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
          Row(
            children: [
              GestureDetector(
                onTap: onPhotoTap,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primary, _purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: profile.photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                profile.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInitials(profile),
                              ),
                            )
                          : _buildInitials(profile),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _card, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditing) ...[
                      TextField(
                        controller: displayNameController,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: const TextStyle(color: _textTertiary),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: _primary),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: _primary, width: 2),
                          ),
                        ),
                        maxLength: 50,
                      ),
                    ] else ...[
                      Text(
                        profile.displayNameOrEmail,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Active User',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(UserProfile profile) {
    return Center(
      child: Text(
        profile.initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Stats Section ─────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final UserProfile profile;
  final BillsProvider billsProvider;
  final NumberFormat currency;

  const _StatsSection({
    required this.profile,
    required this.billsProvider,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final bills = billsProvider.bills;
    final totalBills = bills.length;
    final paidBills = bills.where((bill) => bill.isPaid).length;
    final completionRate = totalBills > 0 ? (paidBills / totalBills * 100) : 0.0;
    final totalSpent = bills
        .where((bill) => bill.isPaid && bill.amount != null)
        .fold<double>(0.0, (sum, bill) => sum + bill.amount!);
    final upcomingBills = bills
        .where((bill) => !bill.isPaid && bill.dueDate.isAfter(DateTime.now()))
        .length;
    final overdueBills = bills
        .where((bill) => !bill.isPaid && bill.dueDate.isBefore(DateTime.now()))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.receipt_long_rounded,
              label: 'Total Bills',
              value: totalBills.toString(),
              color: _blue,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.check_circle_rounded,
              label: 'Paid Bills',
              value: paidBills.toString(),
              color: _green,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.trending_up_rounded,
              label: 'Completion',
              value: '${completionRate.toStringAsFixed(0)}%',
              color: _purple,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.currency_rupee_rounded,
              label: 'Total Spent',
              value: currency.format(totalSpent),
              color: _primary,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.upcoming_rounded,
              label: 'Upcoming',
              value: upcomingBills.toString(),
              color: Colors.orange,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              icon: Icons.warning_rounded,
              label: 'Overdue',
              value: overdueBills.toString(),
              color: _red,
            )),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insights Shortcut ─────────────────────────────────────────────────────────

class _InsightsShortcut extends StatelessWidget {
  const _InsightsShortcut();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InsightsScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: _primary, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending Insights',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Monthly breakdown by category',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: _textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Preferences Section ─────────────────────────────────────────────────────────

class _PreferencesSection extends StatelessWidget {
  final UserProfile profile;

  const _PreferencesSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferences',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _PreferenceTile(
                icon: Icons.access_time_rounded,
                title: 'Timezone',
                value: profile.timezone,
                onTap: () {},
              ),
              _Divider(),
              _PreferenceTile(
                icon: Icons.currency_rupee_rounded,
                title: 'Currency',
                value: profile.currency,
                onTap: () {},
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                value: profile.pushNotificationsEnabled,
                onChanged: (value) {
                  context.read<UserProvider>().updateNotificationSettings(
                        pushNotificationsEnabled: value,
                      );
                },
              ),
              _Divider(),
              _SwitchTile(
                icon: Icons.email_outlined,
                title: 'Email Notifications',
                value: profile.emailNotificationsEnabled,
                onChanged: (value) {
                  context.read<UserProvider>().updateNotificationSettings(
                        emailNotificationsEnabled: value,
                      );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _primary.withOpacity(0.06),
      highlightColor: _primary.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: _textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: _textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _primary,
            activeTrackColor: _primary.withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: _border, height: 1, thickness: 1);
  }
}

// ── Account Section ───────────────────────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  final UserProfile profile;
  final String memberSince;

  const _AccountSection({
    required this.profile,
    required this.memberSince,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _InfoTile(
                icon: Icons.email_outlined,
                title: 'Email Address',
                value: profile.email,
              ),
              _Divider(),
              _InfoTile(
                icon: Icons.calendar_today_outlined,
                title: 'Member Since',
                value: memberSince,
              ),
              _Divider(),
              _InfoTile(
                icon: Icons.fingerprint_outlined,
                title: 'User ID',
                value: profile.uid.substring(0, 8) + '...',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: _textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Danger Section ───────────────────────────────────────────────────────────

class _DangerSection extends StatelessWidget {
  const _DangerSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danger Zone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _red.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _DangerTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'Sign out of your account',
                onTap: () => _showSignOutDialog(context),
              ),
              _Divider(),
              _DangerTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account and data',
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _red.withOpacity(0.06),
      highlightColor: _red.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: _red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: _red.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _red,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

void _showSignOutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await FirebaseAuth.instance.signOut();
          },
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}

void _showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

// ── Delete Account Dialog ─────────────────────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  int _step = 0; // 0 = warning, 1 = password confirmation
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pw = _pwCtrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Re-authenticate so Firebase allows deletion
      final cred =
          EmailAuthProvider.credential(email: user.email!, password: pw);
      await user.reauthenticateWithCredential(cred);

      final db = FirebaseFirestore.instance;
      final uid = user.uid;

      // Delete all bills in the subcollection
      final billsSnap = await db
          .collection('users')
          .doc(uid)
          .collection('bills')
          .get();
      await Future.wait(billsSnap.docs.map((d) => d.reference.delete()));

      // Delete the user document itself
      await db.collection('users').doc(uid).delete();

      // Delete Firebase Auth account — must be last
      await user.delete();

      // AuthWrapper automatically redirects to login when auth state changes
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      final msg =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
              ? 'Incorrect password. Please try again.'
              : (e.message ?? 'Authentication failed. Please try again.');
      setState(() {
        _error = msg;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return AlertDialog(
        backgroundColor: _card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.warning_rounded, color: _red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all your bills. This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: _textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: _textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Continue',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    // Step 1 — password confirmation
    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Confirm Deletion',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your password to permanently delete your account.',
            style: TextStyle(
                fontSize: 14, color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwCtrl,
            obscureText: _obscure,
            autofocus: true,
            onSubmitted: (_) => _loading ? null : _deleteAccount(),
            style: const TextStyle(fontSize: 15, color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Your password',
              hintStyle: const TextStyle(color: _textTertiary),
              errorText: _error,
              filled: true,
              fillColor: const Color(0xFFF5F0EA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textTertiary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
                color: _textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _deleteAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete Forever',
                  style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Photo option row ───────────────────────────────────────────────────────────

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? _textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
