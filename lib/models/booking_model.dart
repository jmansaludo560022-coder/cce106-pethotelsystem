import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic/booking_rules.dart';
import 'add_on_model.dart';

/// A stay reservation (collection: bookings).
///
/// The ERD fields (custID, petID, roomID, dates, totalAmount, status) are kept.
/// Snapshot fields (customerName, petName, roomNum, …) are copied in when the
/// booking is created so admin and customer lists show real names without
/// extra reads (fixes ISS-09 / ISS-21). They are optional so documents created
/// by older versions of the app still load.
class BookingModel {
  final String bookingID;
  final String custID; // customers/{cusID} (Q-01)
  final String petID;
  final String roomID;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final String checkInTimeSlot;
  final double totalAmount;
  final String status;
  final List<SelectedAddOn> selectedAddOns;
  final DateTime createdAt;

  // Snapshot / workflow fields
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String petName;
  final String petType;
  final String roomNum;
  final String roomTypeID;
  final String roomTypeName;
  final double pricePerNight;
  final String source; // 'app' | 'walk_in'
  final String paymentMethod; // chosen at booking time
  final String rejectionReason;

  BookingModel({
    required this.bookingID,
    required this.custID,
    required this.petID,
    required this.roomID,
    required this.checkInDate,
    required this.checkOutDate,
    this.checkInTimeSlot = 'Morning (10:00 AM - 12:00 PM)',
    required this.totalAmount,
    this.status = BookingStatus.pending,
    this.selectedAddOns = const [],
    DateTime? createdAt,
    this.customerName = '',
    this.customerEmail = '',
    this.customerPhone = '',
    this.petName = '',
    this.petType = '',
    this.roomNum = '',
    this.roomTypeID = '',
    this.roomTypeName = '',
    this.pricePerNight = 0,
    this.source = 'app',
    this.paymentMethod = '',
    this.rejectionReason = '',
  }) : createdAt = createdAt ?? DateTime.now();

  int get nightsCount => nightsBetween(checkInDate, checkOutDate);

  String get normalizedStatus => BookingStatus.normalize(status);
  bool get isPending => normalizedStatus == BookingStatus.pending;
  bool get isApproved => normalizedStatus == BookingStatus.approved;
  bool get isCheckedIn => normalizedStatus == BookingStatus.checkedIn;
  bool get isCheckedOut => normalizedStatus == BookingStatus.checkedOut;
  bool get isRejected => normalizedStatus == BookingStatus.rejected;
  bool get isCancelled => normalizedStatus == BookingStatus.cancelled;
  bool get isActive => BookingStatus.active.contains(normalizedStatus);
  bool get isQrPassUnlocked => isApproved || isCheckedIn;
  bool get isWalkIn => source == 'walk_in';

  String get roomLabel => roomNum.isNotEmpty ? 'Room $roomNum' : 'Room';
  String get petLabel => petName.isNotEmpty ? petName : 'Pet';

  String get displayStatus {
    switch (normalizedStatus) {
      case BookingStatus.pending:
        return 'Pending Approval';
      case BookingStatus.approved:
        return 'Approved';
      case BookingStatus.checkedIn:
        return 'Checked In';
      case BookingStatus.checkedOut:
        return 'Checked Out';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawAddOns = data['selectedAddOns'] as List<dynamic>? ?? [];
    return BookingModel(
      bookingID: doc.id,
      custID: data['custID'] ?? '',
      petID: data['petID'] ?? '',
      roomID: data['roomID'] ?? '',
      checkInDate: (data['checkInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkOutDate: (data['checkOutDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 1)),
      checkInTimeSlot: data['checkInTimeSlot'] ?? kCheckInTimeSlots.first,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: BookingStatus.normalize(data['status'] ?? BookingStatus.pending),
      selectedAddOns: rawAddOns.map((e) => SelectedAddOn.fromMap(Map<String, dynamic>.from(e))).toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customerName: data['customerName'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      petName: data['petName'] ?? '',
      petType: data['petType'] ?? '',
      roomNum: data['roomNum'] ?? '',
      roomTypeID: data['roomTypeID'] ?? '',
      roomTypeName: data['roomTypeName'] ?? '',
      pricePerNight: (data['pricePerNight'] as num?)?.toDouble() ?? 0.0,
      source: data['source'] ?? 'app',
      paymentMethod: data['paymentMethod'] ?? '',
      rejectionReason: data['rejectionReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingID': bookingID,
      'custID': custID,
      'petID': petID,
      'roomID': roomID,
      'checkInDate': Timestamp.fromDate(checkInDate),
      'checkOutDate': Timestamp.fromDate(checkOutDate),
      'checkInTimeSlot': checkInTimeSlot,
      'totalAmount': totalAmount,
      'status': BookingStatus.normalize(status),
      'selectedAddOns': selectedAddOns.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'petName': petName,
      'petType': petType,
      'roomNum': roomNum,
      'roomTypeID': roomTypeID,
      'roomTypeName': roomTypeName,
      'pricePerNight': pricePerNight,
      'source': source,
      'paymentMethod': paymentMethod,
      'rejectionReason': rejectionReason,
    };
  }

  BookingModel copyWith({
    String? bookingID,
    String? custID,
    String? petID,
    String? roomID,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    String? checkInTimeSlot,
    double? totalAmount,
    String? status,
    List<SelectedAddOn>? selectedAddOns,
    DateTime? createdAt,
    String? source,
    String? paymentMethod,
  }) {
    return BookingModel(
      bookingID: bookingID ?? this.bookingID,
      custID: custID ?? this.custID,
      petID: petID ?? this.petID,
      roomID: roomID ?? this.roomID,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      checkInTimeSlot: checkInTimeSlot ?? this.checkInTimeSlot,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      selectedAddOns: selectedAddOns ?? this.selectedAddOns,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      petName: petName,
      petType: petType,
      roomNum: roomNum,
      roomTypeID: roomTypeID,
      roomTypeName: roomTypeName,
      pricePerNight: pricePerNight,
      source: source ?? this.source,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      rejectionReason: rejectionReason,
    );
  }
}

/// Privacy-safe copy of a booking's room and dates (collection:
/// room_reservations/{bookingID}). Customers can read these to check
/// availability without being able to read other customers' bookings.
class RoomReservation {
  final String bookingID;
  final String roomID;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final String status;

  const RoomReservation({required this.bookingID, required this.roomID, required this.checkInDate, required this.checkOutDate, required this.status});

  StayRange get stay => StayRange(checkInDate, checkOutDate, status);

  factory RoomReservation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RoomReservation(
      bookingID: doc.id,
      roomID: d['roomID'] ?? '',
      checkInDate: (d['checkInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkOutDate: (d['checkOutDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: BookingStatus.normalize(d['status'] ?? BookingStatus.pending),
    );
  }

  static Map<String, dynamic> mapFor(BookingModel b) => {
        'roomID': b.roomID,
        'checkInDate': Timestamp.fromDate(b.checkInDate),
        'checkOutDate': Timestamp.fromDate(b.checkOutDate),
        'status': BookingStatus.normalize(b.status),
        'custID': b.custID,
      };
}
