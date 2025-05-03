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
  Set<String> _selectedMaterialIds = {};
  bool get _isSelectionMode => _selectedMaterialIds.isNotEmpty;

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
        final pickedFile = result.files.first;
        final fileName = pickedFile.name;
        final ext = path.extension(fileName).toLowerCase().replaceAll('.', '');

        final allowedExtensions = [
          'ppt',
          'pptx',
          'doc',
          'docx',
          'txt',
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'webm',
          'avif',
          'mp4',
        ];

        if (!allowedExtensions.contains(ext)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('File .$ext tidak didukung!')));
          return;
        }

        setState(() {
          _selectedFileName = fileName;
          if (kIsWeb) {
            _selectedFileBytes = pickedFile.bytes;
            _selectedFilePath = null;
          } else {
            _selectedFilePath = pickedFile.path;
            _selectedFileBytes = null;
          }

          if (['jpg', 'jpeg', 'png'].contains(ext)) {
            _materialType = 'image';
          } else {
            _materialType = 'file';
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memilih file: $e')));
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
            fileUrl = supabase.storage
                .from('materials')
                .getPublicUrl(uploadPath);
            fileType = _materialType;
          }
        } else if (!kIsWeb && _selectedFilePath != null) {
          final file = File(_selectedFilePath!);
          final bytes = await file.readAsBytes();
          final resp = await supabase.storage
              .from('materials')
              .uploadBinary(uploadPath, bytes);
          if (resp.isNotEmpty) {
            fileUrl = supabase.storage
                .from('materials')
                .getPublicUrl(uploadPath);
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

      final response =
          await supabase.from('materials').insert({
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error menambahkan materi: $e')));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Materi berhasil dihapus')));
    } catch (e) {
      debugPrint('Error deleting material: $e');
    }
  }

  Future<void> _deleteSelectedMaterial() async {
    try {
      await supabase
          .from('materials')
          .delete()
          .inFilter('id', _selectedMaterialIds.toList());

      setState(() {
        _materials.removeWhere(
          (contact) => _selectedMaterialIds.contains(contact.id),
        );
        _selectedMaterialIds.clear();
      });
    } catch (e) {
      debugPrint('Error deleting selected contacts: $e');
    }
  }

  Future<void> _confirmDeleteMaterial(MaterialItem material) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Materi'),
            content: const Text(
              'Apakah kamu yakin ingin menghapus materi ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteMaterial(material);
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteSelectedMaterials() async {
    if (_selectedMaterialIds.isEmpty) return;

    final count = _selectedMaterialIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Hapus $count materi?'),
            content: Text(
              'Apakah kamu yakin ingin menghapus $count materi yang terpilih?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _deleteSelectedMaterial();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menghapus $count materi')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error membuka file: $e')));
    }
  }

  void _showAddMaterialDialog() {
    final parentContext = context;
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;
    String? _fileErrorMessage;

    _titleController.clear();
    _descriptionController.clear();
    _selectedFilePath = null;
    _selectedFileBytes = null;
    _selectedFileName = null;
    _materialType = 'text';

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
                  title: const Text('Tambah Materi Pembelajaran'),
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
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Judul tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'text',
                                    label: Text('Teks'),
                                    icon: Icon(Icons.text_fields),
                                  ),
                                  ButtonSegment(
                                    value: 'file',
                                    label: Text('File'),
                                    icon: Icon(Icons.attach_file),
                                  ),
                                ],
                                selected: {_materialType},
                                onSelectionChanged: (sel) {
                                  setDialogState(() {
                                    _materialType = sel.first;
                                    _fileErrorMessage = null;
                                  });
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
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Konten tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              CustomTextField(
                                controller: _descriptionController,
                                hintText: 'Deskripsi (opsional)',
                                prefixIcon: Icons.description,
                                validator: null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: CustomButton(
                                  text: 'Pilih File',
                                  isOutlined: true,
                                  onPressed: () async {
                                    try {
                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles(
                                            type: FileType.any,
                                            allowMultiple: false,
                                          );
                                      if (result != null &&
                                          result.files.isNotEmpty) {
                                        final pickedFile = result.files.first;
                                        final fileName = pickedFile.name;
                                        final ext = path
                                            .extension(fileName)
                                            .toLowerCase()
                                            .replaceAll('.', '');

                                        final allowedExtensions = [
                                          'ppt',
                                          'pptx',
                                          'doc',
                                          'docx',
                                          'txt',
                                          'pdf',
                                          'png',
                                          'jpg',
                                          'jpeg',
                                          'webm',
                                          'avif',
                                          'mp4',
                                        ];

                                        if (!allowedExtensions.contains(ext)) {
                                          setDialogState(() {
                                            _fileErrorMessage =
                                                'File .$ext tidak didukung!';
                                            _selectedFileName = null;
                                            _selectedFilePath = null;
                                            _selectedFileBytes = null;
                                          });
                                          return;
                                        }

                                        setDialogState(() {
                                          _selectedFileName = fileName;
                                          _fileErrorMessage = null;

                                          if (kIsWeb) {
                                            _selectedFileBytes =
                                                pickedFile.bytes;
                                            _selectedFilePath = null;
                                          } else {
                                            _selectedFilePath = pickedFile.path;
                                            _selectedFileBytes = null;
                                          }

                                          if ([
                                            'jpg',
                                            'jpeg',
                                            'png',
                                          ].contains(ext)) {
                                            _materialType = 'image';
                                          } else {
                                            _materialType = 'file';
                                          }
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking file: $e');
                                      setDialogState(() {
                                        _fileErrorMessage =
                                            'Terjadi kesalahan saat memilih file.';
                                      });
                                    }
                                  },
                                ),
                              ),
                              if (_selectedFileName != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'File terpilih: $_selectedFileName',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (_fileErrorMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _fileErrorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
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
                        if (_materialType != 'text' &&
                            _selectedFileName == null) {
                          setDialogState(() {
                            _fileErrorMessage =
                                'Silakan pilih file terlebih dahulu';
                          });
                          return;
                        }

                        Navigator.of(dialogContext).pop();

                        await _addMaterial();

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Materi berhasil ditambahkan'),
                          ),
                        );
                      },
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditMaterialDialog(MaterialItem m) {
    final parentContext = context;
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;

    _titleController.text = m.title;
    _descriptionController.text = m.description;
    _selectedFileName = m.fileName;
    _materialType = m.fileType ?? 'text';
    _selectedFilePath = null;
    _selectedFileBytes = null;

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
                  title: const Text('Edit Materi Pembelajaran'),
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
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Judul tidak boleh kosong';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'text',
                                    label: Text('Teks'),
                                    icon: Icon(Icons.text_fields),
                                  ),
                                  ButtonSegment(
                                    value: 'file',
                                    label: Text('File'),
                                    icon: Icon(Icons.attach_file),
                                  ),
                                ],
                                selected: {_materialType},
                                onSelectionChanged: (sel) {
                                  setDialogState(
                                    () => _materialType = sel.first,
                                  );
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
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Konten tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              CustomTextField(
                                controller: _descriptionController,
                                hintText: 'Deskripsi (opsional)',
                                prefixIcon: Icons.description,
                                validator: null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: CustomButton(
                                  text: 'Pilih File',
                                  isOutlined: true,
                                  onPressed: () async {
                                    await _pickFile();
                                    if (!dialogContext.mounted) return;
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                              if (_selectedFileName != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'File terpilih: $_selectedFileName',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
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

                        await _updateMaterial(m);

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Materi berhasil diperbarui'),
                          ),
                        );
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
            fileUrl = supabase.storage
                .from('materials')
                .getPublicUrl(uploadPath);
            fileType = _materialType;
          }
        } else if (!kIsWeb && _selectedFilePath != null) {
          final bytes = await File(_selectedFilePath!).readAsBytes();
          final resp = await supabase.storage
              .from('materials')
              .uploadBinary(uploadPath, bytes);
          if (resp.isNotEmpty) {
            fileUrl = supabase.storage
                .from('materials')
                .getPublicUrl(uploadPath);
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

      final resp =
          await supabase
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memperbarui materi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _materials.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, size: 80, color: Colors.grey),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemBuilder: (context, index) {
                  final m = _materials[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          onTap: () {
                            setState(() {
                              if (_isSelectionMode) {
                                if (_selectedMaterialIds.contains(m.id)) {
                                  _selectedMaterialIds.remove(m.id);
                                } else {
                                  _selectedMaterialIds.add(m.id);
                                }
                              }
                            });
                          },
                          onLongPress: () {
                            setState(() {
                              if (_selectedMaterialIds.contains(m.id)) {
                                _selectedMaterialIds.remove(m.id);
                              } else {
                                _selectedMaterialIds.add(m.id);
                              }
                            });
                          },

                          selected: _selectedMaterialIds.contains(m.id),
                          selectedTileColor: Colors.blue.withValues(alpha: 0.1),

                          title: Text(
                            m.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              m.description.isNotEmpty
                                  ? Text(m.description)
                                  : null,

                          trailing:
                              _isSelectionMode
                                  ? null
                                  : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed:
                                            () => _showEditMaterialDialog(m),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed:
                                            () => _confirmDeleteMaterial(m),
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
                                errorBuilder:
                                    (ctx, e, st) => Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Text(
                                          'Tidak dapat memuat gambar',
                                        ),
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
                          ),
                      ],
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _isSelectionMode
                ? _confirmDeleteSelectedMaterials
                : _showAddMaterialDialog,
        backgroundColor: _isSelectionMode ? Colors.red : null,
        child: Icon(_isSelectionMode ? Icons.delete : Icons.add),
      ),
    );
  }
}
