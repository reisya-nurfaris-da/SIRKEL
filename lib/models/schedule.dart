import 'package:flutter/material.dart';

class Schedule {
  final String id;
  final String userId;
  final String course;
  final String location;
  final String notes;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isRecurring;
  final String? recurrenceType;

  Schedule({
    required this.id,
    required this.userId,
    required this.course,
    required this.location,
    required this.notes,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isRecurring,
    this.recurrenceType,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final startTimeParts = (json['start_time'] as String).split(':');
    final endTimeParts = (json['end_time'] as String).split(':');
    
    return Schedule(
      id: json['id'],
      userId: json['user_id'],
      course: json['course'],
      location: json['location'] ?? '',
      notes: json['notes'] ?? '',
      date: DateTime.parse(json['date']),
      startTime: TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      ),
      isRecurring: json['is_recurring'] ?? false,
      recurrenceType: json['recurrence_type'],
    );
  }
}
