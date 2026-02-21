import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/user_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _bg            = Color(0xFFF5F5F5);
const _card          = Colors.white;
const _textPrimary   = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary  = Color(0xFFB0A9A2);
const _red           = Color(0xFFDC2626);
const _btnDark       = Color(0xFF1C1917);
const _underline     = Color(0xFFE5E7EB);
const _orange        = Color(0xFFF97316);

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
  late final Animation<double>   _cardFade;
  late final Animation<Offset>   _cardSlide;
  late final Animation<double>   _logoScale;

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
        Navigator.pushReplacementNamed(context, widget.redirectRoute ?? '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _loginLoading = false; _loginError = _authMsg(e.code); });
    } catch (_) {
      setState(() { _loginLoading = false; _loginError = 'An unexpected error occurred.'; });
    }
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
      if (mounted) {
        await context.read<UserProvider>().loadUserProfile(cred.user!.uid);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _signupLoading = false; _signupError = _authMsg(e.code); });
    } catch (_) {
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
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Branding ──────────────────────────────────────────────────────
          SizedBox(
            height: h * 0.34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Floating orbs
                AnimatedBuilder(
                  animation: _orbCtrl,
                  builder: (_, __) => Stack(
                    children: [
                      Positioned(
                        top: 10 + _orbCtrl.value * 18,
                        right: -25,
                        child: _Orb(size: 140, opacity: 0.07 + _orbCtrl.value * 0.03),
                      ),
                      Positioned(
                        bottom: 5 + (1 - _orbCtrl.value) * 20,
                        left: -35,
                        child: _Orb(size: 110, opacity: 0.05 + _orbCtrl.value * 0.02),
                      ),
                      Positioned(
                        top: h * 0.06 + _orbCtrl.value * 12,
                        left: w * 0.35,
                        child: _Orb(size: 55, opacity: 0.04 + _orbCtrl.value * 0.03),
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
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'STAY AHEAD OF YOUR BILLS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _textTertiary,
                            letterSpacing: 2.4,
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
              color: selected ? _textPrimary : _textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 28 : 0,
            decoration: BoxDecoration(
              color: _btnDark,
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

  const _LoginTab({
    required this.formKey,
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
                  color: _textTertiary,
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
            const Text(
              'Forgot password?',
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(error!),
            ],
            const SizedBox(height: 32),
            _DarkButton(label: 'Login', loading: loading, onTap: onSubmit),
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
                  color: _textTertiary,
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
            const SizedBox(height: 32),
            _DarkButton(
              label: 'Create Account',
              loading: loading,
              onTap: onSubmit,
            ),
            const _FeatureRow(),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, color: _textPrimary),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textTertiary, fontSize: 14),
            prefixIcon: Icon(icon, color: _textTertiary, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
            suffixIcon: suffix != null
                ? Padding(padding: const EdgeInsets.only(right: 4), child: suffix)
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: _underline),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _underline),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _textPrimary, width: 1.5),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _red, width: 1.5),
            ),
            errorStyle: const TextStyle(color: _red, fontSize: 11),
          ),
        ),
      ],
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
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _btnDark,
          disabledBackgroundColor: _btnDark.withOpacity(0.45),
          padding: const EdgeInsets.symmetric(vertical: 17),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
        color: _red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withOpacity(0.2)),
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
        color: _orange.withOpacity(opacity),
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
    for (final c in _ctls) c.dispose();
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

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _orange),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
