import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, customer }

class UserModel {
  final String userID;
  final String username;
  final String email;
  final UserRole role;
  final String status;
  final String? cusID;
  final DateTime createdAt;
  UserModel({
    required this.userID,
    required this.username,
    required this.email,
    required this.role,
    this.status = 'Active',
    this.cusID,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  static UserRole roleFromString(String? role) {
    if (role?.toLowerCase().trim() == 'admin') {
      return UserRole.admin;
    }
    return UserRole.customer;
  }

  static String roleToString(UserRole role) {
    return role == UserRole.admin ? 'admin' : 'customer';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      userID: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      role: roleFromString(data['role']),
      status: data['status'] ?? 'Active',
      cusID: data['cusID'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'username': username,
      'email': email,
      'role': roleToString(role),
      'status': status,
      'cusID': cusID,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? userID,
    String? username,
    String? email,
    UserRole? role,
    String? status,
    String? cusID,
    DateTime? createdAt,
  }) {
    return UserModel(
      userID: userID ?? this.userID,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      cusID: cusID ?? this.cusID,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
