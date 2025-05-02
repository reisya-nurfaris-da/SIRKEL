import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';
import 'package:sirkel/screens/auth/register_screen.dart';
import 'package:sirkel/screens/home_screen.dart';
import 'package:sirkel/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _animController;
  late Animation<Color?> _bgColorAnim;
  late Animation<Alignment> _iconAlignAnim;
  late Animation<Color?> _iconColorAnim;
  late Animation<double> _fieldsOpacityAnim;

  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_animationsInitialized) {
      _bgColorAnim = ColorTween(
        begin: AppColors.primary,
        end: Colors.white,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.5, 1.0, curve: Curves.ease),
        ),
      );

      _iconAlignAnim = AlignmentTween(
        begin: Alignment.center,
        end: const Alignment(0, -0.6),
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.2, 0.7, curve: Curves.fastOutSlowIn),
        ),
      );

      _iconColorAnim = ColorTween(
        begin: Colors.white,
        end: AppColors.primary,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
        ),
      );

      _fieldsOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
        ),
      );

      _animController.forward();

      _animationsInitialized = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (res.user != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Login gagal, silakan coba lagi.';
        });
      }
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      String customMsg;
      if (lower.contains('invalid login credentials')) {
        customMsg = 'Email atau kata sandi tidak valid';
      } else if (lower.contains('too many requests') ||
          lower.contains('rate limit')) {
        customMsg = 'Terlalu banyak percobaan. Coba lagi nanti.';
      } else {
        customMsg = e.message;
      }
      if (mounted) setState(() => _errorMessage = customMsg);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan tak terduga. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _bgColorAnim.value,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Opacity(
                      opacity: _fieldsOpacityAnim.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 120),
                          const Text(
                            'Sistem Informasi Reminder Kelas & E-learning',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 48),
                          CustomTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            prefixIcon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _passwordController,
                            hintText: 'Kata Sandi',
                            prefixIcon: Icons.lock,
                            obscureText: true,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),
                          CustomButton(
                            text: 'Masuk',
                            isLoading: _isLoading,
                            onPressed: _signIn,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Belum punya akun? Daftar Sekarang',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AlignTransition(
                  alignment: _iconAlignAnim,
                  child: Icon(
                    Icons.school,
                    size: 80,
                    color: _iconColorAnim.value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
