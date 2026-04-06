import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/user_provider.dart';
import '../../services/biometric_service.dart';
import '../../core/theme/app_colors.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

// Branding section (black bg at top)
const _bgStart    = Color(0xFF111111);
const _bgEnd      = Color(0xFF1A1A1A);
const _brandText  = Colors.white;
const _brandDim   = Color(0x99FFFFFF);

// Card / form section (white surface)
const _card        = AppColors.surface;
const _cardBorder  = AppColors.border;
const _formPrimary = AppColors.textPrimary;
const _formSub     = AppColors.textSecondary;
const _formDim     = AppColors.textTertiary;

// Actions
const _lime     = AppColors.primary;
const _limeDark = AppColors.primaryDark;
const _red      = AppColors.red;

// ── Screen ────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final String? redirectRoute;
  const LoginScreen({super.key, this.redirectRoute});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Animations
  late final AnimationController _orbCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _particleCtrl;
  late final Animation<double>   _cardFade;
  late final Animation<Offset>   _cardSlide;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _particleFade;

  // Login
  final _loginKey       = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPwCtrl    = TextEditingController();
  bool  _loginObscure   = true;
  bool  _loginLoading   = false;
  String? _loginError;

  // Signup
  final _signupKey       = GlobalKey<FormState>();
  final _signupNameCtrl  = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPwCtrl    = TextEditingController();
  bool  _signupObscure   = true;
  bool  _signupLoading   = false;
  String? _signupError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    // Particles float
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _particleFade = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _particleCtrl, curve: Curves.easeInOut));

    // Orbs drift
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    // Logo breathing
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    // Card entrance
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _cardFade  = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _orbCtrl.dispose();
    _cardCtrl.dispose();
    _logoCtrl.dispose();
    _particleCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginPwCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPwCtrl.dispose();
    super.dispose();
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_loginKey.currentState?.validate() ?? false)) return;
    setState(() { _loginLoading = true; _loginError = null; });
    try {
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPwCtrl.text,
      );
      if (mounted) {
        await context.read<UserProvider>().loadUserProfile(auth.currentUser!.uid);
        await _offerBiometric();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _loginLoading = false; _loginError = _authMsg(e.code); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loginLoading = false; _loginError = 'An unexpected error occurred.'; });
    }
  }

  // ── Offer Biometric ────────────────────────────────────────────────────────
  // Called once after a successful email/password login. If the device supports
  // biometrics and the user hasn't set a preference yet, show a one-time prompt.

  Future<void> _offerBiometric() async {
    final alreadyEnabled = await BiometricService.isEnabled();
    if (alreadyEnabled) return;

    final available = await BiometricService.isAvailable();
    if (!available) return;

    if (!mounted) return;

    final enable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint_rounded,
                  size: 32, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enable Biometric Login?',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use your fingerprint or face ID to unlock the app next time instead of typing your password.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heroCard,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Enable',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );

    if (enable == true) {
      await BiometricService.setEnabled(true);
    }
  }

  // ── Forgot Password ────────────────────────────────────────────────────────

  void _showForgotPasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(
        initialEmail: _loginEmailCtrl.text.trim(),
      ),
    );
  }

  // ── Signup ─────────────────────────────────────────────────────────────────

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    if (!(_signupKey.currentState?.validate() ?? false)) return;
    setState(() { _signupLoading = true; _signupError = null; });
    try {
      final auth = FirebaseAuth.instance;
      final cred = await auth.createUserWithEmailAndPassword(
        email: _signupEmailCtrl.text.trim(),
        password: _signupPwCtrl.text,
      );
      if (_signupNameCtrl.text.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(_signupNameCtrl.text.trim());
      }
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUserProfile(cred.user!.uid);
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _signupLoading = false; _signupError = _authMsg(e.code); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _signupLoading = false; _signupError = 'An unexpected error occurred.'; });
    }
  }

  String _authMsg(String code) {
    switch (code) {
      case 'user-not-found':       return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':   return 'Incorrect password. Please try again.';
      case 'invalid-email':        return 'Invalid email address.';
      case 'user-disabled':        return 'This account has been disabled.';
      case 'too-many-requests':    return 'Too many attempts. Try again later.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      default:                     return 'Something went wrong. Please try again.';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgStart, _bgEnd],
          ),
        ),
        child: Column(
          children: [
          // ── Branding ──────────────────────────────────────────────────────
          SizedBox(
            height: h * 0.34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Floating particles
                AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, _) => Stack(
                    children: [
                      Positioned(
                        top: 20 + _particleCtrl.value * 30,
                        right: 10 + _particleCtrl.value * 20,
                        child: _Particle(size: 4, opacity: 0.6 + _particleFade.value * 0.4),
                      ),
                      Positioned(
                        bottom: 30 + (1 - _particleCtrl.value) * 25,
                        left: 15 + _particleCtrl.value * 15,
                        child: _Particle(size: 3, opacity: 0.4 + _particleFade.value * 0.3),
                      ),
                      Positioned(
                        top: h * 0.08 + _particleCtrl.value * 18,
                        left: w * 0.25,
                        child: _Particle(size: 5, opacity: 0.5 + _particleFade.value * 0.3),
                      ),
                      Positioned(
                        top: h * 0.15 + (1 - _particleCtrl.value) * 22,
                        right: w * 0.20,
                        child: _Particle(size: 3.5, opacity: 0.7 + _particleFade.value * 0.2),
                      ),
                    ],
                  ),
                ),
                // Floating orbs
                AnimatedBuilder(
                  animation: _orbCtrl,
                  builder: (_, _) => Stack(
                    children: [
                      Positioned(
                        top: 10 + _orbCtrl.value * 18,
                        right: -25,
                        child: _Orb(size: 140, opacity: 0.1 + _orbCtrl.value * 0.05),
                      ),
                      Positioned(
                        bottom: 5 + (1 - _orbCtrl.value) * 20,
                        left: -35,
                        child: _Orb(size: 110, opacity: 0.08 + _orbCtrl.value * 0.04),
                      ),
                      Positioned(
                        top: h * 0.06 + _orbCtrl.value * 12,
                        left: w * 0.35,
                        child: _Orb(size: 55, opacity: 0.06 + _orbCtrl.value * 0.04),
                      ),
                    ],
                  ),
                ),
                // Logo + text
                SafeArea(
                  bottom: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: Image.asset(
                            'assets/icons/icon-512.png',
                            width: 96,
                            height: 96,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'BILL BUDDY',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _brandText,
                            letterSpacing: 3.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'STAY AHEAD OF YOUR BILLS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _brandDim,
                            letterSpacing: 3.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Card ──────────────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TabRow(controller: _tabCtrl),
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _LoginTab(
                              formKey: _loginKey,
                              emailCtrl: _loginEmailCtrl,
                              pwCtrl: _loginPwCtrl,
                              obscure: _loginObscure,
                              onToggle: () => setState(() => _loginObscure = !_loginObscure),
                              loading: _loginLoading,
                              error: _loginError,
                              onSubmit: _login,
                              onForgotPassword: () => _showForgotPasswordSheet(context),
                            ),
                            _SignupTab(
                              formKey: _signupKey,
                              nameCtrl: _signupNameCtrl,
                              emailCtrl: _signupEmailCtrl,
                              pwCtrl: _signupPwCtrl,
                              obscure: _signupObscure,
                              onToggle: () => setState(() => _signupObscure = !_signupObscure),
                              loading: _signupLoading,
                              error: _signupError,
                              onSubmit: _signup,
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ── Tab Row ───────────────────────────────────────────────────────────────────

class _TabRow extends StatefulWidget {
  final TabController controller;
  const _TabRow({required this.controller});

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.controller.index;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              label: 'Login',
              selected: idx == 0,
              onTap: () => widget.controller.animateTo(0),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: 'Signup',
              selected: idx == 1,
              onTap: () => widget.controller.animateTo(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabItem({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? _formPrimary : _formDim,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 28 : 0,
            decoration: BoxDecoration(
              color: _lime,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Login Tab ─────────────────────────────────────────────────────────────────

class _LoginTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final bool obscure;
  final VoidCallback onToggle;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

  const _LoginTab({
    required this.formKey,
    required this.emailCtrl,
    required this.pwCtrl,
    required this.obscure,
    required this.onToggle,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 36),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UnderlineField(
              label: 'Email Address',
              controller: emailCtrl,
              hint: 'hello@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _UnderlineField(
              label: 'Password',
              controller: pwCtrl,
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: obscure,
              suffix: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: _formDim,
                  size: 20,
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Enter your password';
                if ((v ?? '').length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onForgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13,
                  color: _formSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(error!),
            ],
            const SizedBox(height: 24),
            _DarkButton(label: 'Login', loading: loading, onTap: onSubmit),
            const SizedBox(height: 20),
            const _SocialLoginRow(),
            const SizedBox(height: 8),
            const _FeatureRow(),
          ],
        ),
      ),
    );
  }
}

// ── Signup Tab ────────────────────────────────────────────────────────────────

class _SignupTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final bool obscure;
  final VoidCallback onToggle;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  const _SignupTab({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.pwCtrl,
    required this.obscure,
    required this.onToggle,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 36),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UnderlineField(
              label: 'Full Name',
              controller: nameCtrl,
              hint: 'John Doe',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Enter your name';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _UnderlineField(
              label: 'Email Address',
              controller: emailCtrl,
              hint: 'hello@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _UnderlineField(
              label: 'Password',
              controller: pwCtrl,
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: obscure,
              suffix: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: _formDim,
                  size: 20,
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Enter a password';
                if ((v ?? '').length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(error!),
            ],
            const SizedBox(height: 24),
            _DarkButton(
              label: 'Create Account',
              loading: loading,
              onTap: onSubmit,
            ),
            const SizedBox(height: 20),
            const _SocialLoginRow(),
            const SizedBox(height: 8),
            const _FeatureRow(),
          ],
        ),
      ),
    );
  }
}

class _ModernField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ModernField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_ModernField> createState() => _ModernFieldState();
}

class _ModernFieldState extends State<_ModernField> {
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(() {
      final hasText = widget.controller.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = _isFocused ? _formPrimary : _formSub;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? _lime : _cardBorder,
              width: _isFocused ? 1.5 : 1.0,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            style: const TextStyle(fontSize: 15, color: _formPrimary),
            validator: widget.validator,
            onTap: () => setState(() => _isFocused = true),
            onTapOutside: (_) => setState(() => _isFocused = false),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: _formDim, fontSize: 14),
              prefixIcon: Icon(widget.icon, color: _formDim, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
              suffixIcon: widget.suffix != null
                  ? Padding(padding: const EdgeInsets.only(right: 4), child: widget.suffix)
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: const TextStyle(color: _red, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _UnderlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _UnderlineField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernField(
      label: label,
      controller: controller,
      hint: hint,
      icon: icon,
      obscure: obscure,
      suffix: suffix,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}

class _DarkButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _DarkButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lime.withValues(alpha:0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: loading ? AppColors.border : AppColors.heroCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _red.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: _red)),
          ),
        ],
      ),
    );
  }
}

// ── Floating Particle ───────────────────────────────────────────────────────────

class _Particle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Particle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha:opacity),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha:opacity * 0.5),
            blurRadius: size * 2,
            spreadRadius: size * 0.5,
          ),
        ],
      ),
    );
  }
}

// ── Floating Orb ──────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;
  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _lime.withValues(alpha:opacity),
            _lime.withValues(alpha:opacity * 0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _lime.withValues(alpha:opacity * 0.3),
            blurRadius: size * 0.8,
            spreadRadius: size * 0.2,
          ),
        ],
      ),
    );
  }
}

// ── Social Login Row ───────────────────────────────────────────────────────────

class _SocialLoginRow extends StatelessWidget {
  const _SocialLoginRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: _cardBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _formDim,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: _cardBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                icon: Icons.fingerprint,
                label: 'Biometric',
                onTap: () {
                  // TODO: Implement biometric login
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                icon: Icons.message,
                label: 'Google',
                onTap: () {
                  // TODO: Implement Google login
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: _formSub,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _formSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature Row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatefulWidget {
  const _FeatureRow();

  @override
  State<_FeatureRow> createState() => _FeatureRowState();
}

class _FeatureRowState extends State<_FeatureRow> with TickerProviderStateMixin {
  late final List<AnimationController> _ctls;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  static const _features = [
    (Icons.lock_outline_rounded,       'Secure'),
    (Icons.notifications_none_rounded, 'Reminders'),
    (Icons.bar_chart_rounded,          'Insights'),
  ];

  @override
  void initState() {
    super.initState();
    _ctls = List.generate(3, (_) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    ));
    _fades = _ctls.map<Animation<double>>(
      (c) => CurvedAnimation(parent: c, curve: Curves.easeOut),
    ).toList();
    _slides = _ctls.map(
      (c) => Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
    ).toList();

    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 350 + i * 130), () {
        if (mounted) _ctls[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final (icon, label) = _features[i];
          return Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: FadeTransition(
              opacity: _fades[i],
              child: SlideTransition(
                position: _slides[i],
                child: _FeatureChip(icon: icon, label: label),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Forgot Password Sheet ──────────────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() { _loading = false; _sent = true; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'user-not-found'    => 'No account found with this email.',
        'invalid-email'     => 'Invalid email address.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _                   => 'Something went wrong. Please try again.',
      };
      setState(() { _loading = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: _sent ? _SuccessView(
          email: _emailCtrl.text.trim(),
          onDone: () => Navigator.pop(context),
        ) : _FormView(
          emailCtrl: _emailCtrl,
          loading: _loading,
          error: _error,
          onSend: _send,
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _FormView({
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Icon
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha:0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset_rounded,
              size: 26, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 16),

        // Title + subtitle
        const Text(
          'Reset your password',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Email field
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: InputBorder.none,
              hintText: 'hello@example.com',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
              prefixIcon: Icon(Icons.mail_outline_rounded,
                  color: AppColors.textTertiary, size: 20),
            ),
            onChanged: (_) {},
          ),
        ),

        // Error
        if (error != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: AppColors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.red)),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // Send button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.heroCard,
              disabledBackgroundColor: AppColors.border,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.textSecondary),
                  )
                : const Text('Send Reset Link',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),

        // Cancel
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onCancel,
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  final VoidCallback onDone;
  const _SuccessView({required this.email, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Success icon
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha:0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 32, color: AppColors.green),
        ),
        const SizedBox(height: 20),

        const Text(
          'Check your inbox',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a password reset link to\n$email",
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          "Didn't get it? Check your spam folder.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Feature Chip ──────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _lime.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _lime.withValues(alpha:0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _limeDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _formPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
