class MaterialItem {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? content;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final DateTime createdAt;

  MaterialItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.content,
    this.fileUrl,
    this.fileType,
    this.fileName,
    required this.createdAt,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'] ?? '',
      content: json['content'],
      fileUrl: json['file_url'],
      fileType: json['file_type'],
      fileName: json['file_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
