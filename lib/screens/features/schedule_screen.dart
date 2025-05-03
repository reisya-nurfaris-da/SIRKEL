import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/models/schedule.dart';
import 'package:sirkel/theme/app_theme.dart';
import 'package:sirkel/utils/constants.dart';
import 'package:sirkel/widgets/custom_button.dart';
import 'package:sirkel/widgets/custom_text_field.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Set<String> _selectedScheduleIds = {};
  bool get _isSelectionMode => _selectedScheduleIds.isNotEmpty;

  final _courseController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now().replacing(
    hour: TimeOfDay.now().hour + 1,
  );

  List<Schedule> _schedules = [];
  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurrenceType = 'weekly';

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _courseController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await supabase
          .from('schedules')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id);

      setState(() {
        _schedules =
            data.map((schedule) => Schedule.fromJson(schedule)).toList();
      });
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSchedule() async {
    if (_courseController.text.trim().isEmpty) {
      return;
    }

    try {
      final newSchedule = Schedule(
        id: '',
        userId: supabase.auth.currentUser!.id,
        course: _courseController.text.trim(),
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        date: _selectedDay,
        startTime: _startTime,
        endTime: _endTime,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring ? _recurrenceType : null,
      );

      final response =
          await supabase.from('schedules').insert({
            'user_id': newSchedule.userId,
            'course': newSchedule.course,
            'location': newSchedule.location,
            'notes': newSchedule.notes,
            'date': newSchedule.date.toIso8601String(),
            'start_time':
                '${newSchedule.startTime.hour}:${newSchedule.startTime.minute}',
            'end_time':
                '${newSchedule.endTime.hour}:${newSchedule.endTime.minute}',
            'is_recurring': newSchedule.isRecurring,
            'recurrence_type': newSchedule.recurrenceType,
          }).select();

      if (response.isNotEmpty) {
        final insertedSchedule = Schedule.fromJson(response.first);
        setState(() {
          _schedules.add(insertedSchedule);
        });

        _courseController.clear();
        _locationController.clear();
        _notesController.clear();
        _isRecurring = false;
      }
    } catch (e) {
      debugPrint('Error adding schedule: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error menambahkan jadwal: $e')));
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      await supabase.from('schedules').delete().eq('id', scheduleId);
      setState(() {
        _schedules.removeWhere((schedule) => schedule.id == scheduleId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jadwal berhasil dihapus')));
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
    }
  }

  Future<void> _deleteSelectedSchedules() async {
    try {
      final count = _selectedScheduleIds.length;

      await supabase
          .from('schedules')
          .delete()
          .inFilter('id', _selectedScheduleIds.toList());

      setState(() {
        _schedules.removeWhere(
          (schedule) => _selectedScheduleIds.contains(schedule.id),
        );
        _selectedScheduleIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menghapus $count jadwal')),
      );
    } catch (e) {
      debugPrint('Error deleting selected schedules: $e');
    }
  }

  Future<void> _confirmDeleteSchedule(String scheduleId) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Jadwal'),
            content: const Text(
              'Apakah kamu yakin ingin menghapus jadwal ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteSchedule(scheduleId);
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteSelectedSchedules() async {
    if (_selectedScheduleIds.isEmpty) return;

    final count = _selectedScheduleIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Hapus $count jadwal?'),
            content: Text(
              'Apakah kamu yakin ingin menghapus $count jadwal yang terpilih?',
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
      await _deleteSelectedSchedules();
    }
  }

  List<Schedule> _getSchedulesForDay(DateTime day) {
    return _schedules.where((schedule) {
      if (schedule.isRecurring && schedule.recurrenceType == 'weekly') {
        return schedule.date.weekday == day.weekday;
      } else {
        return schedule.date.year == day.year &&
            schedule.date.month == day.month &&
            schedule.date.day == day.day;
      }
    }).toList();
  }

  void _showAddScheduleDialog() {
    final parentContext = context;
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;

    _courseController.clear();
    _locationController.clear();
    _notesController.clear();
    _startTime = TimeOfDay.now();
    _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
    _isRecurring = false;

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
                  title: const Text('Tambah Jadwal Kuliah'),
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
                              controller: _courseController,
                              hintText: 'Nama Mata Kuliah',
                              prefixIcon: Icons.book,
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Nama mata kuliah tidak boleh kosong'
                                          : null,
                            ),

                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _locationController,
                              hintText: 'Lokasi (opsional)',
                              prefixIcon: Icons.location_on,
                              validator: null,
                            ),

                            const SizedBox(height: 16),

                            ListTile(
                              title: const Text('Tanggal'),
                              subtitle: Text(
                                DateFormat(
                                  Constants.dateFormat,
                                ).format(_selectedDay),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: _selectedDay,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => _selectedDay = picked);
                                }
                              },
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    title: const Text('Waktu Mulai'),
                                    subtitle: Text(
                                      _startTime.format(parentContext),
                                    ),
                                    trailing: const Icon(Icons.access_time),
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: _startTime,
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          _startTime = picked;
                                          if (_endTime.hour < picked.hour ||
                                              (_endTime.hour == picked.hour &&
                                                  _endTime.minute <
                                                      picked.minute)) {
                                            _endTime = TimeOfDay(
                                              hour: picked.hour + 1,
                                              minute: picked.minute,
                                            );
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    title: const Text('Waktu Selesai'),
                                    subtitle: Text(
                                      _endTime.format(parentContext),
                                    ),
                                    trailing: const Icon(Icons.access_time),
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: _endTime,
                                      );
                                      if (picked != null) {
                                        setDialogState(() => _endTime = picked);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SwitchListTile(
                              title: const Text('Jadwal Berulang (Mingguan)'),
                              value: _isRecurring,
                              onChanged:
                                  (v) => setDialogState(() => _isRecurring = v),
                            ),

                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _notesController,
                              hintText: 'Catatan (opsional)',
                              prefixIcon: Icons.note,
                              validator: null,
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
                        await _addSchedule();

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Jadwal berhasil ditambahkan'),
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

  void _showEditScheduleDialog(Schedule s) {
    final parentContext = context;
    final _formKey = GlobalKey<FormState>();
    bool _submitted = false;

    _courseController.text = s.course;
    _locationController.text = s.location;
    _notesController.text = s.notes;
    _selectedDay = s.date;
    _focusedDay = s.date;
    _startTime = s.startTime;
    _endTime = s.endTime;
    _isRecurring = s.isRecurring;

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
                  title: const Text('Edit Jadwal Kuliah'),
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
                              controller: _courseController,
                              hintText: 'Nama Mata Kuliah',
                              prefixIcon: Icons.book,
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Nama mata kuliah tidak boleh kosong'
                                          : null,
                            ),

                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _locationController,
                              hintText: 'Lokasi (opsional)',
                              prefixIcon: Icons.location_on,
                              validator: null,
                            ),

                            const SizedBox(height: 16),

                            ListTile(
                              title: const Text('Tanggal'),
                              subtitle: Text(
                                DateFormat(
                                  Constants.dateFormat,
                                ).format(_selectedDay),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: _selectedDay,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => _selectedDay = picked);
                                }
                              },
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    title: const Text('Waktu Mulai'),
                                    subtitle: Text(
                                      _startTime.format(parentContext),
                                    ),
                                    trailing: const Icon(Icons.access_time),
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: _startTime,
                                      );
                                      if (picked != null) {
                                        setDialogState(
                                          () => _startTime = picked,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    title: const Text('Waktu Selesai'),
                                    subtitle: Text(
                                      _endTime.format(parentContext),
                                    ),
                                    trailing: const Icon(Icons.access_time),
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: _endTime,
                                      );
                                      if (picked != null) {
                                        setDialogState(() => _endTime = picked);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SwitchListTile(
                              title: const Text('Jadwal Berulang (Mingguan)'),
                              value: _isRecurring,
                              onChanged:
                                  (v) => setDialogState(() => _isRecurring = v),
                            ),

                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _notesController,
                              hintText: 'Catatan (opsional)',
                              prefixIcon: Icons.note,
                              validator: null,
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
                        await _updateSchedule(s);

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Jadwal berhasil diperbarui'),
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

  Future<void> _updateSchedule(Schedule s) async {
    if (_courseController.text.trim().isEmpty) return;

    try {
      final upd = {
        'course': _courseController.text.trim(),
        'location': _locationController.text.trim(),
        'notes': _notesController.text.trim(),
        'date': _selectedDay.toIso8601String(),
        'start_time': '${_startTime.hour}:${_startTime.minute}',
        'end_time': '${_endTime.hour}:${_endTime.minute}',
        'is_recurring': _isRecurring,
        'recurrence_type': _isRecurring ? _recurrenceType : null,
      };

      final response =
          await supabase
              .from('schedules')
              .update(upd)
              .eq('id', s.id)
              .select()
              .single();

      setState(() {
        final idx = _schedules.indexWhere((x) => x.id == s.id);
        if (idx != -1) _schedules[idx] = Schedule.fromJson(response);
      });

      _courseController.clear();
      _locationController.clear();
      _notesController.clear();
      _isRecurring = false;
    } catch (e) {
      debugPrint('Error updating schedule: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memperbarui jadwal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final todaysSchedules = _getSchedulesForDay(_selectedDay);

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;

                        _selectedScheduleIds.clear();
                      });
                    },
                    eventLoader: _getSchedulesForDay,
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(formatButtonVisible: false),
                  ),
                  const Divider(),
                  Expanded(
                    child:
                        todaysSchedules.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Tidak ada jadwal untuk hari ini',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CustomButton(
                                    text: 'Tambah Jadwal',
                                    onPressed: _showAddScheduleDialog,
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              itemCount: todaysSchedules.length,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                80,
                              ),
                              itemBuilder: (context, index) {
                                final schedule = todaysSchedules[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: ListTile(
                                    onTap: () {
                                      setState(() {
                                        if (_isSelectionMode) {
                                          if (_selectedScheduleIds.contains(
                                            schedule.id,
                                          )) {
                                            _selectedScheduleIds.remove(
                                              schedule.id,
                                            );
                                          } else {
                                            _selectedScheduleIds.add(
                                              schedule.id,
                                            );
                                          }
                                        } else {
                                          _showEditScheduleDialog(schedule);
                                        }
                                      });
                                    },
                                    onLongPress: () {
                                      setState(() {
                                        if (_selectedScheduleIds.contains(
                                          schedule.id,
                                        )) {
                                          _selectedScheduleIds.remove(
                                            schedule.id,
                                          );
                                        } else {
                                          _selectedScheduleIds.add(schedule.id);
                                        }
                                      });
                                    },
                                    selected: _selectedScheduleIds.contains(
                                      schedule.id,
                                    ),
                                    selectedTileColor: AppColors.primary
                                        .withValues(alpha: 0.1),

                                    title: Text(
                                      schedule.course,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (schedule.location.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(schedule.location),
                                              ],
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${schedule.startTime.format(context)} - ${schedule.endTime.format(context)}',
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (schedule.isRecurring)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.repeat,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Berulang mingguan',
                                                  style: const TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (schedule.notes.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(schedule.notes),
                                          ),
                                      ],
                                    ),
                                    trailing:
                                        !_isSelectionMode
                                            ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  onPressed:
                                                      () =>
                                                          _showEditScheduleDialog(
                                                            schedule,
                                                          ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),
                                                  onPressed:
                                                      () =>
                                                          _confirmDeleteSchedule(
                                                            schedule.id,
                                                          ),
                                                ),
                                              ],
                                            )
                                            : null,
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _isSelectionMode
                ? _confirmDeleteSelectedSchedules
                : _showAddScheduleDialog,
        backgroundColor: _isSelectionMode ? Colors.red : null,
        child: Icon(_isSelectionMode ? Icons.delete : Icons.add),
      ),
    );
  }
}
