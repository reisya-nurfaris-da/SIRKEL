class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime deadline;
  final bool isCompleted;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.isCompleted,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'] ?? '',
      deadline: DateTime.parse(json['deadline']),
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? deadline,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
