import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/models/announcement.dart';
import 'package:sirkel/utils/constants.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  List<Announcement> _announcements = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _announcements = data.map((announcement) => Announcement.fromJson(announcement)).toList();
      });
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addAnnouncement() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      return;
    }

    try {
      final newAnnouncement = Announcement(
        id: '',
        userId: supabase.auth.currentUser!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        createdBy: '',
      );

      final userData = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', newAnnouncement.userId)
          .single();
      
      final userName = userData['full_name'] ?? 'Anonim';

      final response = await supabase.from('announcements').insert({
        'user_id': newAnnouncement.userId,
        'title': newAnnouncement.title,
        'content': newAnnouncement.content,
        'created_by': userName,
      }).select();

      if (response.isNotEmpty) {
        final insertedAnnouncement = Announcement.fromJson(response.first);
        setState(() {
          _announcements.insert(0, insertedAnnouncement);
        });
        
        _titleController.clear();
        _contentController.clear();
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error adding announcement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menambahkan pengumuman: $e')),
      );
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    try {
      final announcement = _announcements.firstWhere((a) => a.id == announcementId);
      
      if (announcement.userId != supabase.auth.currentUser!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda hanya dapat menghapus pengumuman yang Anda buat')),
        );
        return;
      }
      
      await supabase.from('announcements').delete().eq('id', announcementId);
      setState(() {
        _announcements.removeWhere((announcement) => announcement.id == announcementId);
      });
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
    }
  }

  void _showAddAnnouncementDialog() {
    setState(() {
      _titleController.clear();
      _contentController.clear();
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Pengumuman'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _titleController,
                hintText: 'Judul',
                prefixIcon: Icons.title,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _contentController,
                hintText: 'Konten',
                prefixIcon: Icons.description,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: _addAnnouncement,
            child: const Text('Posting'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.announcement,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada pengumuman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Jadilah yang pertama membuat pengumuman',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Buat Pengumuman',
                        onPressed: _showAddAnnouncementDialog,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _announcements.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final announcement = _announcements[index];
                    final isCurrentUserAnnouncement = 
                        announcement.userId == supabase.auth.currentUser!.id;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    announcement.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (isCurrentUserAnnouncement)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteAnnouncement(announcement.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(announcement.content),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Diposting oleh: ${announcement.createdBy}',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  DateFormat(Constants.dateFormat)
                                      .format(announcement.createdAt),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAnnouncementDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
