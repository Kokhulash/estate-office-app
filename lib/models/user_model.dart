class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? department;
  final String role; // student, faculty, employee, jnr, ae, admin
  final bool isVerified;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.department,
    required this.role,
    this.isVerified = false,
  });

  bool get isNaiveUser => ['student', 'faculty', 'employee'].contains(role);
  bool get isEngineer => ['jnr', 'ae'].contains(role);
  bool get isJnr => role == 'jnr';
  bool get isAe => role == 'ae';
  bool get isAdmin => role == 'admin';

  String get roleDisplayName {
    switch (role) {
      case 'student':
        return 'Student';
      case 'faculty':
        return 'Faculty';
      case 'employee':
        return 'Campus Staff';
      case 'jnr':
        return 'Junior Engineer (JNR)';
      case 'ae':
        return 'Assistant Engineer (AE)';
      case 'admin':
        return 'Super Administrator';
      default:
        return role.toUpperCase();
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      department: json['department'],
      role: json['role'] ?? 'student',
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'role': role,
      'is_verified': isVerified,
    };
  }
}
