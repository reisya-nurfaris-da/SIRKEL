import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';
import 'package:sirkel/screens/auth/register_screen.dart';
import 'package:sirkel/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
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
    } catch (e) {
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.school, size: 80, color: Color(0xFF1a73e8)),
                const SizedBox(height: 24),
                const Text(
                  'Sistem Informasi Reminder Kelas & E-learning',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  child: const Text('Belum punya akun? Daftar Sekarang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
