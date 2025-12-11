class Contact {
  final int id;
  final int userId;
  final int contactId;
  final String username;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.userId,
    required this.contactId,
    required this.username,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as int,
      userId: json['userId'] as int,
      contactId: json['contactId'] as int,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'contactId': contactId,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

