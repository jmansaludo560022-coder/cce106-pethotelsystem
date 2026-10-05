import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewID;
  final String custID;
  final String custName;
  final String? petName;
  final String? bookingID;
  final String? roomTypeName;
  final double rating;
  final String title;
  final String comment;
  final String status; // 'Approved', 'Pending', 'Hidden'
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;

  ReviewModel({
    required this.reviewID,
    required this.custID,
    required this.custName,
    this.petName,
    this.bookingID,
    this.roomTypeName,
    required this.rating,
    required this.title,
    required this.comment,
    this.status = 'Approved',
    this.adminReply,
    this.repliedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReviewModel(
      reviewID: doc.id,
      custID: data['custID'] ?? '',
      custName: data['custName'] ?? 'Valued Customer',
      petName: data['petName'],
      bookingID: data['bookingID'],
      roomTypeName: data['roomTypeName'],
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      title: data['title'] ?? '',
      comment: data['comment'] ?? '',
      status: data['status'] ?? 'Approved',
      adminReply: data['adminReply'],
      repliedAt: (data['repliedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewID': reviewID,
      'custID': custID,
      'custName': custName,
      'petName': petName,
      'bookingID': bookingID,
      'roomTypeName': roomTypeName,
      'rating': rating,
      'title': title,
      'comment': comment,
      'status': status,
      'adminReply': adminReply,
      'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ReviewModel copyWith({
    String? reviewID,
    String? custID,
    String? custName,
    String? petName,
    String? bookingID,
    String? roomTypeName,
    double? rating,
    String? title,
    String? comment,
    String? status,
    String? adminReply,
    DateTime? repliedAt,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      reviewID: reviewID ?? this.reviewID,
      custID: custID ?? this.custID,
      custName: custName ?? this.custName,
      petName: petName ?? this.petName,
      bookingID: bookingID ?? this.bookingID,
      roomTypeName: roomTypeName ?? this.roomTypeName,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      status: status ?? this.status,
      adminReply: adminReply ?? this.adminReply,
      repliedAt: repliedAt ?? this.repliedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
