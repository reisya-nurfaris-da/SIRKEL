import 'package:flutter/material.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/models/contact.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _notesController = TextEditingController();

  List<Contact> _contacts = [];
  bool _isLoading = false;
  String _contactType = 'lecturer';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await supabase
          .from('contacts')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('name');

      setState(() {
        _contacts = data.map((contact) => Contact.fromJson(contact)).toList();
      });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addContact() async {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    try {
      final newContact = Contact(
        id: '',
        userId: supabase.auth.currentUser!.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _roleController.text.trim(),
        notes: _notesController.text.trim(),
        type: _contactType,
      );

      final response =
          await supabase.from('contacts').insert({
            'user_id': newContact.userId,
            'name': newContact.name,
            'email': newContact.email,
            'phone': newContact.phone,
            'role': newContact.role,
            'notes': newContact.notes,
            'type': newContact.type,
          }).select();

      if (response.isNotEmpty) {
        final insertedContact = Contact.fromJson(response.first);
        setState(() {
          _contacts.add(insertedContact);
          _contacts.sort((a, b) => a.name.compareTo(b.name));
        });

        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _roleController.clear();
        _notesController.clear();

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error adding contact: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error menambahkan kontak: $e')));
    }
  }

  Future<void> _deleteContact(String contactId) async {
    try {
      await supabase.from('contacts').delete().eq('id', contactId);
      setState(() {
        _contacts.removeWhere((contact) => contact.id == contactId);
      });
    } catch (e) {
      debugPrint('Error deleting contact: $e');
    }
  }

  Future<void> _confirmDeleteContact(String contactId) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Kontak'),
            content: const Text(
              'Apakah kamu yakin ingin menghapus kontak ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteContact(contactId);
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat melakukan panggilan')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat mengirim email')),
      );
    }
  }

  void _showAddContactDialog() {
    setState(() {
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _roleController.clear();
      _notesController.clear();
      _contactType = 'lecturer';
    });

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Tambah Kontak'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'lecturer',
                              label: Text('Dosen'),
                              icon: Icon(Icons.school),
                            ),
                            ButtonSegment(
                              value: 'student',
                              label: Text('Mahasiswa'),
                              icon: Icon(Icons.person),
                            ),
                          ],
                          selected: {_contactType},
                          onSelectionChanged: (Set<String> selection) {
                            setDialogState(() {
                              _contactType = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _nameController,
                          hintText: 'Nama',
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
                          controller: _phoneController,
                          hintText: 'Telepon',
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _roleController,
                          hintText:
                              _contactType == 'lecturer'
                                  ? 'Jurusan/Mata Kuliah'
                                  : 'Kelas/Jurusan',
                          prefixIcon: Icons.work,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _notesController,
                          hintText: 'Catatan (opsional)',
                          prefixIcon: Icons.note,
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
                      onPressed: _addContact,
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditContactDialog(Contact contact) {
    _contactType = contact.type;
    _nameController.text = contact.name;
    _emailController.text = contact.email;
    _phoneController.text = contact.phone;
    _roleController.text = contact.role;
    _notesController.text = contact.notes;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('Edit Kontak'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'lecturer',
                              label: Text('Dosen'),
                              icon: Icon(Icons.school),
                            ),
                            ButtonSegment(
                              value: 'student',
                              label: Text('Mahasiswa'),
                              icon: Icon(Icons.person),
                            ),
                          ],
                          selected: {_contactType},
                          onSelectionChanged:
                              (sel) => setDialogState(() {
                                _contactType = sel.first;
                              }),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _nameController,
                          hintText: 'Nama',
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
                          controller: _phoneController,
                          hintText: 'Telepon',
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _roleController,
                          hintText:
                              _contactType == 'lecturer'
                                  ? 'Jurusan/Mata Kuliah'
                                  : 'Kelas/Jurusan',
                          prefixIcon: Icons.work,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _notesController,
                          hintText: 'Catatan (opsional)',
                          prefixIcon: Icons.note,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _updateContact(contact.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _updateContact(String contactId) async {
    if (_nameController.text.trim().isEmpty) return;

    try {
      final updated = {
        'type': _contactType,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _roleController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final response =
          await supabase
              .from('contacts')
              .update(updated)
              .eq('id', contactId)
              .select()
              .single();

      setState(() {
        final idx = _contacts.indexWhere((c) => c.id == contactId);
        if (idx != -1) {
          _contacts[idx] = Contact.fromJson(response);
          _contacts.sort((a, b) => a.name.compareTo(b.name));
        }
      });

      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _roleController.clear();
      _notesController.clear();
    } catch (e) {
      debugPrint('Error updating contact: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memperbarui kontak: $e')));
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          contact.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          contact.role.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari kontak',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child:
                        _contacts.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.contacts,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Belum ada kontak',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tambahkan kontak pertama Anda',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 24),
                                  CustomButton(
                                    text: 'Tambah Kontak',
                                    onPressed: _showAddContactDialog,
                                  ),
                                ],
                              ),
                            )
                            : _filteredContacts.isEmpty
                            ? const Center(
                              child: Text('Tidak ada kontak yang ditemukan'),
                            )
                            : ListView.builder(
                              itemCount: _filteredContacts.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final contact = _filteredContacts[index];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          contact.type == 'lecturer'
                                              ? Colors.blue
                                              : Colors.green,
                                      child: Icon(
                                        contact.type == 'lecturer'
                                            ? Icons.school
                                            : Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      contact.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (contact.role.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(contact.role),
                                          ),
                                        if (contact.email.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: GestureDetector(
                                              onTap:
                                                  () =>
                                                      _sendEmail(contact.email),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.email,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    contact.email,
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (contact.phone.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: GestureDetector(
                                              onTap:
                                                  () =>
                                                      _callPhone(contact.phone),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    contact.phone,
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed:
                                              () => _showEditContactDialog(
                                                contact,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed:
                                              () => _confirmDeleteContact(
                                                contact.id,
                                              ),
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
