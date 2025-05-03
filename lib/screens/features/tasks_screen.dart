import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/models/task.dart';
import 'package:sirkel/utils/constants.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  Set<String> _selectedTaskIds = {};
  bool get _isSelectionMode => _selectedTaskIds.isNotEmpty;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  List<Task> _tasks = [];
  bool _isLoading = false;
  bool _isTitleValid(String title) {
    final regex = RegExp(r'^[a-zA-Z0-9\s]+$');
    return regex.hasMatch(title);
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await supabase
          .from('tasks')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('deadline', ascending: true);

      setState(() {
        _tasks = data.map((task) => Task.fromJson(task)).toList();
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addTask() async {
    final trimmedTitle = _titleController.text.trim();
    if (trimmedTitle.isEmpty || !_isTitleValid(trimmedTitle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul hanya boleh huruf dan angka')),
      );
      return;
    }

    try {
      final newTask = Task(
        id: '',
        userId: supabase.auth.currentUser!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        deadline: _deadline,
        isCompleted: false,
      );

      final response =
          await supabase.from('tasks').insert({
            'user_id': newTask.userId,
            'title': newTask.title,
            'description': newTask.description,
            'deadline': newTask.deadline.toIso8601String(),
            'is_completed': newTask.isCompleted,
          }).select();

      if (response.isNotEmpty) {
        final insertedTask = Task.fromJson(response.first);
        setState(() {
          _tasks.add(insertedTask);
          _tasks.sort((a, b) => a.deadline.compareTo(b.deadline));
        });

        _titleController.clear();
        _descriptionController.clear();
        _deadline = DateTime.now().add(const Duration(days: 1));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil ditambahkan')),
        );
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error menambahkan tugas: $e')));
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      await supabase
          .from('tasks')
          .update({'is_completed': !task.isCompleted})
          .eq('id', task.id);

      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(
            isCompleted: !task.isCompleted,
          );
        }
      });
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await supabase.from('tasks').delete().eq('id', taskId);
      setState(() {
        _tasks.removeWhere((task) => task.id == taskId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tugas berhasil dihapus')));
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _confirmDeleteTask(String taskId) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Tugas'),
            content: const Text('Apakah kamu yakin ingin menghapus tugas ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteTask(taskId);
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteSelectedTasks() async {
    if (_selectedTaskIds.isEmpty) return;

    final count = _selectedTaskIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Hapus $count tugas?'),
            content: Text(
              'Apakah kamu yakin ingin menghapus $count tugas yang terpilih?',
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
      await _deleteSelectedTasks();
    }
  }

  Future<void> _deleteSelectedTasks() async {
    try {
      final count = _selectedTaskIds.length;
      await supabase
          .from('tasks')
          .delete()
          .inFilter('id', _selectedTaskIds.toList());

      setState(() {
        _tasks.removeWhere((task) => _selectedTaskIds.contains(task.id));
        _selectedTaskIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menghapus $count tugas')),
      );
    } catch (e) {
      debugPrint('Error deleting selected tasks: $e');
    }
  }

  String _getRemainingDays(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(deadline.year, deadline.month, deadline.day);

    final difference = dueDate.difference(today).inDays;

    if (difference < 0) {
      return 'Terlambat';
    } else if (difference == 0) {
      return 'Hari ini';
    } else if (difference == 1) {
      return '1 hari lagi';
    } else {
      return '$difference hari lagi';
    }
  }

  void _showAddTaskDialog() {
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;

    _titleController.clear();
    _descriptionController.clear();
    _deadline = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  title: const Text('Tambah Tugas Baru'),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
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
                              hintText: 'Judul Tugas',
                              prefixIcon: Icons.title,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Judul tidak boleh kosong';
                                }
                                if (!_isTitleValid(v.trim())) {
                                  return 'Judul hanya boleh huruf dan angka';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _descriptionController,
                              hintText: 'Deskripsi (opsional)',
                              prefixIcon: Icons.description,
                              validator: null,
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('Tenggat Waktu'),
                              subtitle: Text(
                                DateFormat(
                                  Constants.dateFormat,
                                ).format(_deadline),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _deadline,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _deadline = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        setDialogState(() => _submitted = true);
                        if (!_formKey.currentState!.validate()) return;

                        Navigator.of(context).pop();
                        await _addTask();
                      },
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditTaskDialog(Task task) {
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;

    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _deadline = task.deadline;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  title: const Text('Edit Tugas'),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
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
                              hintText: 'Judul Tugas',
                              prefixIcon: Icons.title,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Judul tidak boleh kosong';
                                }
                                if (!_isTitleValid(v.trim())) {
                                  return 'Judul hanya boleh huruf dan angka';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _descriptionController,
                              hintText: 'Deskripsi (opsional)',
                              prefixIcon: Icons.description,
                              validator: null,
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('Tenggat Waktu'),
                              subtitle: Text(
                                DateFormat(
                                  Constants.dateFormat,
                                ).format(_deadline),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _deadline,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _deadline = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        setDialogState(() => _submitted = true);
                        if (!_formKey.currentState!.validate()) return;

                        Navigator.of(context).pop();
                        await _updateTask(task);
                      },
                      child: const Text('Simpan'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _updateTask(Task task) async {
    final trimmedTitle = _titleController.text.trim();
    if (trimmedTitle.isEmpty || !_isTitleValid(trimmedTitle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul hanya boleh huruf dan angka')),
      );
      return;
    }

    try {
      await supabase
          .from('tasks')
          .update({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'deadline': _deadline.toIso8601String(),
          })
          .eq('id', task.id);

      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            deadline: _deadline,
          );
          _tasks.sort((a, b) => a.deadline.compareTo(b.deadline));
        }
      });

      _titleController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tugas berhasil diubah')));
    } catch (e) {
      debugPrint('Error updating task: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error mengubah tugas: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.task_alt, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada tugas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tambahkan tugas pertama Anda',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Tambah Tugas',
                      onPressed: _showAddTaskDialog,
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _tasks.length,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final remainingDays = _getRemainingDays(task.deadline);
                  final isOverdue = remainingDays == 'Terlambat';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          if (_isSelectionMode) {
                            if (_selectedTaskIds.contains(task.id)) {
                              _selectedTaskIds.remove(task.id);
                            } else {
                              _selectedTaskIds.add(task.id);
                            }
                          } else {
                            _toggleTaskCompletion(task);
                          }
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          if (_selectedTaskIds.contains(task.id)) {
                            _selectedTaskIds.remove(task.id);
                          } else {
                            _selectedTaskIds.add(task.id);
                          }
                        });
                      },

                      selected: _selectedTaskIds.contains(task.id),
                      selectedTileColor: Colors.blue.withValues(alpha: 0.1),

                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          decoration:
                              task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(task.description),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color:
                                    isOverdue && !task.isCompleted
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  Constants.dateFormat,
                                ).format(task.deadline),
                                style: TextStyle(
                                  color:
                                      isOverdue && !task.isCompleted
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  remainingDays,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isOverdue && !task.isCompleted
                                            ? Colors.white
                                            : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      trailing:
                          _isSelectionMode
                              ? null
                              : ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 0,
                                  maxWidth: 120,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: task.isCompleted,
                                      onChanged:
                                          (_) => _toggleTaskCompletion(task),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed:
                                          () => _showEditTaskDialog(task),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed:
                                          () => _confirmDeleteTask(task.id),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _isSelectionMode ? _confirmDeleteSelectedTasks : _showAddTaskDialog,
        backgroundColor: _isSelectionMode ? Colors.red : null,
        child: Icon(_isSelectionMode ? Icons.delete : Icons.add),
      ),
    );
  }
}
