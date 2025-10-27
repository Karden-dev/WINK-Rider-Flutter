// lib/models/user.dart

class User {
  final int id;
  final String name;
  final String role;
  final String phoneNumber;
  final String token; // Le JWT (JSON Web Token)

  User({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    required this.token,
  });

  // Factory constructor pour créer un objet User à partir du JSON de l'API
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      phoneNumber: json['phoneNumber'] as String,
      token: json['token'] as String,
    );
  }

  // Convertit l'objet User en JSON (pour le stockage local dans SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phoneNumber': phoneNumber,
      'token': token,
    };
  }
}