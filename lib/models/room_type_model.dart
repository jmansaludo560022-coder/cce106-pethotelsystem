import 'package:cloud_firestore/cloud_firestore.dart';

class RoomTypeModel {
  final String roomTypeID;
  final String typeName; // 'Standard Room', 'Luxury Suite'
  final String description;
  final double pricePerNight;
  final int maxCapacity;

  RoomTypeModel({
    required this.roomTypeID,
    required this.typeName,
    required this.description,
    required this.pricePerNight,
    required this.maxCapacity,
  });

  factory RoomTypeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RoomTypeModel(
      roomTypeID: doc.id,
      typeName: data['typeName'] ?? '',
      description: data['description'] ?? '',
      pricePerNight: (data['pricePerNight'] as num?)?.toDouble() ?? 0.0,
      maxCapacity: (data['maxCapacity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomTypeID': roomTypeID,
      'typeName': typeName,
      'description': description,
      'pricePerNight': pricePerNight,
      'maxCapacity': maxCapacity,
    };
  }
}
