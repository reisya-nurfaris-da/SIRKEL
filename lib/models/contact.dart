class Contact {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String notes;
  final String type;

  Contact({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.notes,
    required this.type,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      notes: json['notes'] ?? '',
      type: json['type'] ?? 'student',
    );
  }
}
