import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:sirkel/main.dart';
import 'package:sirkel/models/material_item.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<MaterialItem> _materials = [];
  bool _isLoading = false;

  Uint8List? _selectedFileBytes;
  String? _selectedFilePath;
  String? _selectedFileName;
  String _materialType = 'text';

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('materials')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);
      setState(() {
        _materials = data.map((m) => MaterialItem.fromJson(m)).toList();
      });
    } catch (e) {
      debugPrint('Error loading materials: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFileName = result.files.first.name;
          if (kIsWeb) {
            _selectedFileBytes = result.files.first.bytes;
            _selectedFilePath = null;
          } else {
            _selectedFilePath = result.files.first.path;
            _selectedFileBytes = null;
          }
          final ext = path.extension(_selectedFileName!).toLowerCase();
          _materialType = ['.jpg', '.jpeg', '.png', '.gif'].contains(ext)
              ? 'image'
              : 'file';
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error memilih file: $e')),
      );
    }
  }

  Future<void> _addMaterial() async {
    if (_titleController.text.trim().isEmpty) return;

    try {
      String? fileUrl;
      String? fileType;

      if ((_selectedFilePath != null || _selectedFileBytes != null) &&
          _materialType != 'text') {
        final fileExt = path.extension(_selectedFileName!).replaceAll('.', '');
        final uploadPath =
            '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        if (kIsWeb && _selectedFileBytes != null) {
          final resp = await supabase.storage
              .from('materials')
              .uploadBinary(uploadPath, _selectedFileBytes!);
          if (resp.isNotEmpty) {
            fileUrl =
                supabase.storage.from('materials').getPublicUrl(uploadPath);
            fileType = _materialType;
          }
        } else if (!kIsWeb && _selectedFilePath != null) {
          final file = File(_selectedFilePath!);
          final bytes = await file.readAsBytes();
          final resp = await supabase.storage
              .from('materials')
              .uploadBinary(uploadPath, bytes);
          if (resp.isNotEmpty) {
            fileUrl =
                supabase.storage.from('materials').getPublicUrl(uploadPath);
            fileType = _materialType;
          }
        }
      }

      final newMat = MaterialItem(
        id: '',
        userId: supabase.auth.currentUser!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        content:
            _materialType == 'text' ? _descriptionController.text.trim() : null,
        fileUrl: fileUrl,
        fileType: fileType,
        fileName: _selectedFileName,
        createdAt: DateTime.now(),
      );

      final response = await supabase.from('materials').insert({
        'user_id': newMat.userId,
        'title': newMat.title,
        'description': newMat.description,
        'content': newMat.content,
        'file_url': newMat.fileUrl,
        'file_type': newMat.fileType,
        'file_name': newMat.fileName,
      }).select();

      if (response.isNotEmpty) {
        final inserted = MaterialItem.fromJson(response.first);
        setState(() {
          _materials.insert(0, inserted);
        });
      }
      _titleController.clear();
      _descriptionController.clear();
      _selectedFilePath = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _materialType = 'text';
    } catch (e) {
      debugPrint('Error adding material: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menambahkan materi: $e')),
      );
    }
  }

  Future<void> _deleteMaterial(MaterialItem material) async {
    try {
      if (material.fileUrl != null) {
        final filePath = material.fileUrl!.split('/').last;
        await supabase.storage.from('materials').remove([filePath]);
      }
      await supabase.from('materials').delete().eq('id', material.id);
      setState(() {
        _materials.removeWhere((m) => m.id == material.id);
      });
    } catch (e) {
      debugPrint('Error deleting material: $e');
    }
  }

  Future<void> _openFile(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error membuka file: $e')),
      );
    }
  }

  void _showAddMaterialDialog() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _selectedFilePath = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _materialType = 'text';
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: const Text('Tambah Materi Pembelajaran'),
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
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'text',
                          label: Text('Teks'),
                          icon: Icon(Icons.text_fields)),
                      ButtonSegment(
                          value: 'file',
                          label: Text('File'),
                          icon: Icon(Icons.attach_file)),
                    ],
                    selected: {_materialType},
                    onSelectionChanged: (sel) {
                      setDialogState(() => _materialType = sel.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_materialType == 'text') ...[
                  CustomTextField(
                    controller: _descriptionController,
                    hintText: 'Konten',
                    prefixIcon: Icons.description,
                    keyboardType: TextInputType.multiline,
                  ),
                ] else ...[
                  CustomTextField(
                    controller: _descriptionController,
                    hintText: 'Deskripsi (opsional)',
                    prefixIcon: Icons.description,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Pilih File',
                      isOutlined: true,
                      onPressed: () async {
                        await _pickFile();
                        if (!context.mounted) return;
                        setDialogState(() {});
                      },
                    ),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'File terpilih: $_selectedFileName',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                await _addMaterial();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMaterialDialog(MaterialItem m) {
    _titleController.text = m.title;
    _descriptionController.text = m.description;
    _selectedFileName = m.fileName;
    _materialType = m.fileType ?? 'text';
    _selectedFilePath = null;
    _selectedFileBytes = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: const Text('Edit Materi Pembelajaran'),
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
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'text',
                          label: Text('Teks'),
                          icon: Icon(Icons.text_fields)),
                      ButtonSegment(
                          value: 'file',
                          label: Text('File'),
                          icon: Icon(Icons.attach_file)),
                    ],
                    selected: {_materialType},
                    onSelectionChanged: (sel) {
                      setDialogState(() => _materialType = sel.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_materialType == 'text') ...[
                  CustomTextField(
                    controller: _descriptionController,
                    hintText: 'Konten',
                    prefixIcon: Icons.description,
                    keyboardType: TextInputType.multiline,
                  ),
                ] else ...[
                  CustomTextField(
                    controller: _descriptionController,
                    hintText: 'Deskripsi (opsional)',
                    prefixIcon: Icons.description,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Pilih File',
                      isOutlined: true,
                      onPressed: () async {
                        await _pickFile();
                        if (!context.mounted) return;
                        setDialogState(() {});
                      },
                    ),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'File terpilih: $_selectedFileName',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                await _updateMaterial(m);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMaterial(MaterialItem m) async {
    if (_titleController.text.trim().isEmpty) return;

    try {
      String? fileUrl = m.fileUrl;
      String? fileType = m.fileType;

      if ((_selectedFilePath != null || _selectedFileBytes != null) &&
          _materialType != 'text') {
        final ext = path.extension(_selectedFileName!).replaceAll('.', '');
        final uploadPath =
            '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

        if (kIsWeb && _selectedFileBytes != null) {
          final resp = await supabase.storage
              .from('materials')
              .uploadBinary(uploadPath, _selectedFileBytes!);
          if (resp.isNotEmpty) {
            fileUrl =
                supabase.storage.from('materials').getPublicUrl(uploadPath);
            fileType = _materialType;
          }
        } else if (!kIsWeb && _selectedFilePath != null) {
          final bytes = await File(_selectedFilePath!).readAsBytes();
          final resp = await supabase.storage
              .from('materials')
              .uploadBinary(uploadPath, bytes);
          if (resp.isNotEmpty) {
            fileUrl =
                supabase.storage.from('materials').getPublicUrl(uploadPath);
            fileType = _materialType;
          }
        }
      }

      final updated = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'content':
            _materialType == 'text' ? _descriptionController.text.trim() : null,
        'file_url': fileUrl,
        'file_type': fileType,
        'file_name': _selectedFileName,
      };

      final resp = await supabase
          .from('materials')
          .update(updated)
          .eq('id', m.id)
          .select()
          .single();

      setState(() {
        final i = _materials.indexWhere((item) => item.id == m.id);
        if (i != -1) _materials[i] = MaterialItem.fromJson(resp);
      });

      _selectedFilePath = null;
      _selectedFileBytes = null;
    } catch (e) {
      debugPrint('Error updating material: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error memperbarui materi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.book,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada materi pembelajaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tambahkan materi pertama Anda',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Tambah Materi',
                        onPressed: _showAddMaterialDialog,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _materials.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final m = _materials[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(m.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: m.description.isNotEmpty
                                ? Text(m.description)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEditMaterialDialog(m),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteMaterial(m),
                                ),
                              ],
                            ),
                          ),
                          if (m.fileType == 'image' && m.fileUrl != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: GestureDetector(
                                onTap: () => _openFile(m.fileUrl!),
                                child: Image.network(
                                  m.fileUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, e, st) => Container(
                                    height: 200,
                                    width: double.infinity,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Text('Tidak dapat memuat gambar'),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (m.fileType == 'file' && m.fileUrl != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CustomButton(
                                text: 'Buka ${m.fileName ?? 'File'}',
                                onPressed: () => _openFile(m.fileUrl!),
                                isOutlined: true,
                              ),
                            )
                          else if (m.content != null && m.fileType != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(m.content!),
                            )
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMaterialDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
