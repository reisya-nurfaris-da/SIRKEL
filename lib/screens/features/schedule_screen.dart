import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sirkel/main.dart';
import 'package:sirkel/models/schedule.dart';
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

        Navigator.of(context).pop();
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
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
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
    setState(() {
      _courseController.clear();
      _locationController.clear();
      _notesController.clear();
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
      _isRecurring = false;
      _recurrenceType = 'weekly';
    });

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Tambah Jadwal Kuliah'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomTextField(
                          controller: _courseController,
                          hintText: 'Nama Mata Kuliah',
                          prefixIcon: Icons.book,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _locationController,
                          hintText: 'Lokasi',
                          prefixIcon: Icons.location_on,
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
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDay,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );

                            if (pickedDate != null) {
                              setDialogState(() {
                                _selectedDay = pickedDate;
                              });
                            }
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                title: const Text('Waktu Mulai'),
                                subtitle: Text(_startTime.format(context)),
                                trailing: const Icon(Icons.access_time),
                                onTap: () async {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: _startTime,
                                  );

                                  if (pickedTime != null) {
                                    setDialogState(() {
                                      _startTime = pickedTime;
                                      if (_endTime.hour < _startTime.hour ||
                                          (_endTime.hour == _startTime.hour &&
                                              _endTime.minute <
                                                  _startTime.minute)) {
                                        _endTime = TimeOfDay(
                                          hour: _startTime.hour + 1,
                                          minute: _startTime.minute,
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
                                subtitle: Text(_endTime.format(context)),
                                trailing: const Icon(Icons.access_time),
                                onTap: () async {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: _endTime,
                                  );

                                  if (pickedTime != null) {
                                    setDialogState(() {
                                      _endTime = pickedTime;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          title: const Text('Jadwal Berulang'),
                          value: _isRecurring,
                          onChanged: (value) {
                            setDialogState(() {
                              _isRecurring = value;
                            });
                          },
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
                      onPressed: _addSchedule,
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditScheduleDialog(Schedule s) {
    _courseController.text = s.course;
    _locationController.text = s.location;
    _notesController.text = s.notes;
    _selectedDay = s.date;
    _focusedDay = s.date;
    _startTime = s.startTime;
    _endTime = s.endTime;
    _isRecurring = s.isRecurring;
    _recurrenceType = s.recurrenceType ?? 'weekly';

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('Edit Jadwal Kuliah'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomTextField(
                          controller: _courseController,
                          hintText: 'Nama Mata Kuliah',
                          prefixIcon: Icons.book,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _locationController,
                          hintText: 'Lokasi',
                          prefixIcon: Icons.location_on,
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
                            final p = await showDatePicker(
                              context: ctx,
                              initialDate: _selectedDay,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (p != null)
                              setDialogState(() => _selectedDay = p);
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                title: const Text('Waktu Mulai'),
                                subtitle: Text(_startTime.format(ctx)),
                                trailing: const Icon(Icons.access_time),
                                onTap: () async {
                                  final p = await showTimePicker(
                                    context: ctx,
                                    initialTime: _startTime,
                                  );
                                  if (p != null) {
                                    setDialogState(() {
                                      _startTime = p;
                                      if (_endTime.hour < p.hour ||
                                          (_endTime.hour == p.hour &&
                                              _endTime.minute < p.minute)) {
                                        _endTime = TimeOfDay(
                                          hour: p.hour + 1,
                                          minute: p.minute,
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
                                subtitle: Text(_endTime.format(ctx)),
                                trailing: const Icon(Icons.access_time),
                                onTap: () async {
                                  final p = await showTimePicker(
                                    context: ctx,
                                    initialTime: _endTime,
                                  );
                                  if (p != null)
                                    setDialogState(() => _endTime = p);
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          title: const Text('Jadwal Berulang'),
                          value: _isRecurring,
                          onChanged:
                              (v) => setDialogState(() => _isRecurring = v),
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
                        await _updateSchedule(s);
                        if (ctx.mounted) Navigator.of(ctx).pop();
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
                      });
                    },
                    eventLoader: _getSchedulesForDay,
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(formatButtonVisible: false),
                  ),
                  const Divider(),
                  Expanded(
                    child:
                        _getSchedulesForDay(_selectedDay).isEmpty
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
                              itemCount:
                                  _getSchedulesForDay(_selectedDay).length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final schedule =
                                    _getSchedulesForDay(_selectedDay)[index];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: ListTile(
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
                                                  'Berulang ${schedule.recurrenceType == 'weekly' ? 'mingguan' : ''}',
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
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed:
                                              () => _showEditScheduleDialog(
                                                schedule,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed:
                                              () =>
                                                  _deleteSchedule(schedule.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
