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
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _announcements = data.map((a) => Announcement.fromJson(a)).toList();
      });
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAnnouncement() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

    try {
      final newAnn = Announcement(
        id: '',
        userId: supabase.auth.currentUser!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        createdBy: '',
      );

      final profile =
          await supabase
              .from('profiles')
              .select('full_name')
              .eq('id', newAnn.userId)
              .single();

      final userName = profile['full_name'] ?? 'Anonim';

      final response =
          await supabase.from('announcements').insert({
            'user_id': newAnn.userId,
            'title': newAnn.title,
            'content': newAnn.content,
            'created_by': userName,
          }).select();

      if (response.isNotEmpty) {
        final inserted = Announcement.fromJson(response.first);
        setState(() {
          _announcements.insert(0, inserted);
        });
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
      final ann = _announcements.firstWhere((a) => a.id == announcementId);

      if (ann.userId != supabase.auth.currentUser!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Anda hanya dapat menghapus pengumuman yang Anda buat',
            ),
          ),
        );
        return;
      }

      await supabase.from('announcements').delete().eq('id', announcementId);

      setState(() {
        _announcements.removeWhere((a) => a.id == announcementId);
      });
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
    }
  }

  Future<void> _confirmDeleteAnnouncement(String announcementId) async {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Hapus Pengumuman'),
            content: const Text(
              'Apakah kamu yakin ingin menghapus pengumuman ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _deleteAnnouncement(announcementId);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Pengumuman berhasil dihapus'),
                    ),
                  );
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _showAddAnnouncementDialog() {
    final parentContext = context;
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;

    _titleController.clear();
    _contentController.clear();

    showDialog(
      context: parentContext,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  title: const Text('Tambah Pengumuman'),
                  content: SizedBox(
                    width: MediaQuery.of(parentContext).size.width * 0.8,
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        autovalidateMode:
                            _submitted
                                ? AutovalidateMode.always
                                : AutovalidateMode.disabled,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomTextField(
                              controller: _titleController,
                              hintText: 'Judul',
                              prefixIcon: Icons.title,
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Judul tidak boleh kosong'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _contentController,
                              hintText: 'Konten',
                              prefixIcon: Icons.description,
                              keyboardType: TextInputType.multiline,
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Konten tidak boleh kosong'
                                          : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        setDialogState(() => _submitted = true);
                        if (!_formKey.currentState!.validate()) return;

                        Navigator.of(dialogContext).pop();
                        await _addAnnouncement();

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Pengumuman berhasil diposting'),
                          ),
                        );
                      },
                      child: const Text('Posting'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemBuilder: (context, index) {
                  final ann = _announcements[index];
                  final isMine = ann.userId == supabase.auth.currentUser!.id;

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
                                  ann.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              if (isMine)
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed:
                                      () => _confirmDeleteAnnouncement(ann.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(ann.content),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  ann.createdBy,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  Constants.dateFormat,
                                ).format(ann.createdAt),
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
