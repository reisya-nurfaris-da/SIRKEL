class Announcement {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final String createdBy;

  Announcement({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.createdBy,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      createdBy: json['created_by'] ?? '',
    );
  }
}
