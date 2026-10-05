import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String roomID;
  final String roomTypeID;
  final String roomNum;
  final String roomPhoto;
  final String status; // 'Available', 'Occupied', 'Maintenance'

  RoomModel({
    required this.roomID,
    required this.roomTypeID,
    required this.roomNum,
    this.roomPhoto = '',
    this.status = 'Available',
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RoomModel(
      roomID: doc.id,
      roomTypeID: data['roomTypeID'] ?? '',
      roomNum: data['roomNum'] ?? '',
      roomPhoto: data['roomPhoto'] ?? '',
      status: data['status'] ?? 'Available',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomID': roomID,
      'roomTypeID': roomTypeID,
      'roomNum': roomNum,
      'roomPhoto': roomPhoto,
      'status': status,
    };
  }

  RoomModel copyWith({
    String? roomID,
    String? roomTypeID,
    String? roomNum,
    String? roomPhoto,
    String? status,
  }) {
    return RoomModel(
      roomID: roomID ?? this.roomID,
      roomTypeID: roomTypeID ?? this.roomTypeID,
      roomNum: roomNum ?? this.roomNum,
      roomPhoto: roomPhoto ?? this.roomPhoto,
      status: status ?? this.status,
    );
  }
}
