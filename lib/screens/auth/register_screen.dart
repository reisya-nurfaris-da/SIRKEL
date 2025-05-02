import 'package:flutter/material.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.split(' ').length < 2) {
      setState(() {
        _errorMessage = 'Nama lengkap harus terdiri dari minimal 2 kata';
      });
      return;
    }

    if (RegExp(r'\d').hasMatch(name)) {
      setState(() {
        _errorMessage = 'Nama tidak boleh mengandung angka';
      });
      return;
    }

    if (!email.endsWith('@gmail.com')) {
      setState(() {
        _errorMessage = 'Email harus diakhiri dengan @gmail.com';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password harus minimal 6 karakter';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': _nameController.text.trim()},
      );

      if (!mounted) return;

      if (response.user != null) {
        try {
          await supabase.from('profiles').upsert({
            'id': response.user!.id,
            'full_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
          });

          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;

          Navigator.of(context).pushReplacementNamed('/home');
        } catch (profileError) {
          debugPrint('Error creating profile: $profileError');
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;

          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() {
          _errorMessage = 'Pendaftaran gagal';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Akun Baru')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Nama Lengkap',
                  prefixIcon: Icons.person,
                ),
                const SizedBox(height: 16),
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
                  text: 'Daftar',
                  isLoading: _isLoading,
                  onPressed: _signUp,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Sudah punya akun? Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
