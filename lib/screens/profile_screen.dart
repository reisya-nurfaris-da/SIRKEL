import 'package:flutter/material.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _user = supabase.auth.currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      if (_user?.id == null) return;

      final userData = await supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();
      
      setState(() {
        _nameController.text = userData['full_name'] ?? '';
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_user?.id == null) return;

      await supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
      }).eq('id', _user!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _nameController.text.isNotEmpty 
                      ? _nameController.text[0].toUpperCase() 
                      : 'M',
                  style: const TextStyle(fontSize: 40.0, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _nameController,
              hintText: 'Nama Lengkap',
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: 16),
            Text(
              'Email: ${_user?.email ?? ''}',
              style: const TextStyle(fontSize: 16),
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
              text: 'Perbarui Profil',
              isLoading: _isLoading,
              onPressed: _updateProfile,
            ),
          ],
        ),
      ),
    );
  }
}
