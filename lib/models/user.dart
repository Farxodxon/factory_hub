class FactoryUser {
  final String id;
  final String username;
  final String email;
  final String createdAt;

  FactoryUser({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
  });

  factory FactoryUser.fromJson(Map<String, dynamic> json) {
    return FactoryUser(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'createdAt': createdAt,
    };
  }
}
