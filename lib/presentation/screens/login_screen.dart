import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/user_provider.dart';

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _red = Color(0xFFDC2626);

class LoginScreen extends StatefulWidget {
  final String? redirectRoute;
  const LoginScreen({super.key, this.redirectRoute});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const _mockEmail = 'demo@smartbill.com';
  static const _mockPassword = 'demo1234';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      
      if (mounted) {
        // Initialize user profile after successful login
        await context.read<UserProvider>().loadUserProfile(auth.currentUser!.uid);
        
        // Navigate to intended route or home
        final destination = widget.redirectRoute ?? '/home';
        Navigator.pushReplacementNamed(context, destination);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        switch (e.code) {
          case 'user-not-found':
            _error = 'No account found with this email. Please register first.';
            break;
          case 'wrong-password':
            _error = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            _error = 'Invalid email address.';
            break;
          case 'user-disabled':
            _error = 'This account has been disabled.';
            break;
          case 'too-many-requests':
            _error = 'Too many failed attempts. Please try again later.';
            break;
          default:
            _error = 'Login failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 52, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _primary.withOpacity(0.20)),
                      ),
                      child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: _primary,
                          size: 30),
                    ),
                    const SizedBox(height: 30),

                    // Heading
                    const Text(
                      'Smart Bill\nReminder',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        height: 1.15,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sign in to manage your bills',
                      style: TextStyle(
                          fontSize: 14, color: _textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 40),

                    // Email
                    const _Label('Email address'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _emailCtrl,
                      hint: 'demo@smartbill.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Enter your email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password
                    const _Label('Password'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _textTertiary,
                          size: 20,
                        ),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Enter your password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                              fontSize: 13,
                              color: _primary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _red.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: _red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 13, color: _red)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sign In
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          disabledBackgroundColor: _primary.withOpacity(0.45),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Sign In',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(fontSize: 14, color: _textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                                fontSize: 14,
                                color: _primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: _textSecondary));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
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
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: _textTertiary, size: 20),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 1.5)),
        errorStyle: const TextStyle(color: _red, fontSize: 12),
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: _textSecondary)),
        ),
        const Text('·  ', style: TextStyle(color: _textTertiary)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace')),
        ),
      ],
    );
  }
}
