import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/ph_locations.dart';
import '../core/utils/ph_phone.dart';

/// A pet owner (collection: customers). Registered customers have a
/// [userID] (their Firebase Auth UID); walk-in customers created by the admin
/// have none (master spec §8.5, Q-05).
class CustomerModel {
  final String cusID;
  final String? userID;
  final String cusFName;
  final String cusMName;
  final String cusLName;
  final String phoneNum;
  final String email;
  /// Single-line address — kept filled (spec §10.2) so existing screens work.
  final String address;

  /// Structured PSGC address (spec §10.2). Empty for records created before it.
  final PhAddress phAddress;
  final bool isWalkIn;
  final DateTime createdAt;

  CustomerModel({
    required this.cusID,
    this.userID,
    required this.cusFName,
    this.cusMName = '',
    required this.cusLName,
    required this.phoneNum,
    required this.email,
    required this.address,
    this.phAddress = PhAddress.empty,
    this.isWalkIn = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fullName {
    final parts = [cusFName, cusMName, cusLName].where((p) => p.trim().isNotEmpty);
    return parts.join(' ');
  }

  String get firstName => cusFName.isNotEmpty ? cusFName : fullName;
  bool get hasAccount => (userID ?? '').isNotEmpty;

  /// `+63 917 123 4567` (spec §10.1).
  String get phoneDisplay => PhPhone.display(phoneNum);

  /// Lower-cased search text for admin search (WALK-002).
  String get searchText => '$fullName $email $phoneNum ${PhPhone.localDigits(phoneNum)} $address'.toLowerCase();

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerModel(
      cusID: doc.id,
      userID: data['userID'],
      cusFName: data['cusFName'] ?? '',
      cusMName: data['cusMName'] ?? '',
      cusLName: data['cusLName'] ?? '',
      // Spec §10.1: older "09…" numbers are normalized to +63 on read.
      phoneNum: PhPhone.normalize(data['phoneNum']) ?? (data['phoneNum'] ?? ''),
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      phAddress: data['phAddress'] is Map ? PhAddress.fromMap(Map<String, dynamic>.from(data['phAddress'])) : PhAddress.empty,
      isWalkIn: data['isWalkIn'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cusID': cusID,
      'userID': userID,
      'cusFName': cusFName,
      'cusMName': cusMName,
      'cusLName': cusLName,
      'phoneNum': phoneNum,
      'email': email.trim().toLowerCase(),
      'address': address,
      'phAddress': phAddress.toMap(),
      'isWalkIn': isWalkIn,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CustomerModel copyWith({
    String? cusID,
    String? userID,
    String? cusFName,
    String? cusMName,
    String? cusLName,
    String? phoneNum,
    String? email,
    String? address,
    PhAddress? phAddress,
    bool? isWalkIn,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      cusID: cusID ?? this.cusID,
      userID: userID ?? this.userID,
      cusFName: cusFName ?? this.cusFName,
      cusMName: cusMName ?? this.cusMName,
      cusLName: cusLName ?? this.cusLName,
      phoneNum: phoneNum ?? this.phoneNum,
      email: email ?? this.email,
      address: address ?? this.address,
      phAddress: phAddress ?? this.phAddress,
      isWalkIn: isWalkIn ?? this.isWalkIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
