import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/screens/features/tasks_screen.dart';
import 'package:sirkel/screens/features/materials_screen.dart';
import 'package:sirkel/screens/features/schedule_screen.dart';
import 'package:sirkel/screens/features/contacts_screen.dart';
import 'package:sirkel/screens/features/announcements_screen.dart';
import 'package:sirkel/screens/profile_screen.dart';
import 'package:sirkel/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _user = supabase.auth.currentUser;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      if (_user?.id == null) return;

      final userData =
          await supabase.from('profiles').select().eq('id', _user!.id).single();

      setState(() {
        _userName = userData['full_name'] ?? 'Mahasiswa';
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();

    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const TasksScreen(),
      const MaterialsScreen(),
      const ScheduleScreen(),
      const ContactsScreen(),
      const AnnouncementsScreen(),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.light, AppColors.primary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          title: const Text(
            'SIRKEL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_userName),
              accountEmail: Text(_user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
                  style: const TextStyle(fontSize: 24.0, color: Colors.white),
                ),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.light, AppColors.primary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.task),
              title: const Text('Tugas'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Materi Pembelajaran'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Jadwal Kuliah'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Kontak'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('Pengumuman'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Keluar'),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tugas'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Materi'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Jadwal',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Kontak'),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Pengumuman',
          ),
        ],
      ),
    );
  }
}
