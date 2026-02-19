import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/user_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF8F5);
const _card = Colors.white;
const _border = Color(0xFFEDE6DC);
const _primary = Color(0xFFF97316);
const _textPrimary = Color(0xFF1C1917);
const _textSecondary = Color(0xFF78716C);
const _textTertiary = Color(0xFFA8A29E);
const _red = Color(0xFFDC2626);
const _green = Color(0xFF16A34A);

// ── Screen ────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

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
    _confirmPasswordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      
      // Create user with email and password
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // Update display name if provided
      if (_nameCtrl.text.trim().isNotEmpty) {
        await userCredential.user?.updateDisplayName(_nameCtrl.text.trim());
      }

      if (mounted) {
        // Clear any existing errors first
        setState(() {
          _error = null;
        });
        
        // Initialize user profile after successful registration
        try {
          await context.read<UserProvider>().loadUserProfile(userCredential.user!.uid);
          Navigator.pushReplacementNamed(context, '/home');
        } catch (e) {
          setState(() {
            _loading = false;
            _error = 'Failed to create user profile: ${e.toString()}';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        switch (e.code) {
          case 'weak-password':
            _error = 'Password is too weak. Please choose a stronger password.';
            break;
          case 'email-already-in-use':
            _error = 'An account with this email already exists. Please sign in.';
            break;
          case 'invalid-email':
            _error = 'Invalid email address.';
            break;
          case 'operation-not-allowed':
            _error = 'Email/password accounts are not enabled.';
            break;
          default:
            _error = 'Registration failed: ${e.message}';
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
    return WillPopScope(
      onWillPop: () async {
        // If user is authenticated, sign them out when going back from registration
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
        return true; // Allow back navigation
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
            onPressed: () async {
              // If user is authenticated, sign them out when going back from registration
              if (FirebaseAuth.instance.currentUser != null) {
                await FirebaseAuth.instance.signOut();
              }
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                      'Create Account',
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
                      'Sign up to start managing your bills',
                      style: TextStyle(
                          fontSize: 14, color: _textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 40),

                    // Name
                    const _Label('Full Name (Optional)'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _nameCtrl,
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.name,
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isNotEmpty && value.length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Email
                    const _Label('Email address'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _emailCtrl,
                      hint: 'your@email.com',
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
                      obscure: _obscurePassword,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
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
                    const SizedBox(height: 18),

                    // Confirm Password
                    const _Label('Confirm Password'),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _confirmPasswordCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscureConfirm,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        child: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _textTertiary,
                          size: 20,
                        ),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Confirm your password';
                        if (value != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

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

                    // Sign Up
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
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
                            : const Text('Create Account',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(fontSize: 14, color: _textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                                fontSize: 14,
                                color: _primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Terms
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _green.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.security_rounded,
                                    size: 14, color: _green),
                              ),
                              const SizedBox(width: 8),
                              const Text('Secure & Private',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your data is encrypted and stored securely. We never share your information with third parties.',
                            style: TextStyle(
                                fontSize: 12, 
                                color: _textSecondary,
                                height: 1.4),
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
