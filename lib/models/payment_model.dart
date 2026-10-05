import 'package:cloud_firestore/cloud_firestore.dart';

/// Money received for a booking (collection: payments). A booking may have
/// several payments (ERD). [paymentStatus] is the booking's status right after
/// this payment was recorded (PAY-003); the live status is always recomputed
/// from the sum of payments.
class PaymentModel {
  final String paymentID;
  final String bookingID;
  final String? custID;
  final DateTime paymentDate;
  final double amount;
  final String paymentMethod;
  final String paymentStatus; // 'Unpaid', 'Partial', 'Paid'
  final String referenceNumber;
  final String customerName;
  final bool isSimulated; // true = simulated e-wallet (no real provider)
  final String recordedBy; // 'customer' | 'admin'
  final DateTime createdAt;

  PaymentModel({
    required this.paymentID,
    required this.bookingID,
    this.custID,
    DateTime? paymentDate,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.referenceNumber = '',
    this.customerName = '',
    this.isSimulated = false,
    this.recordedBy = 'admin',
    DateTime? createdAt,
  })  : paymentDate = paymentDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel(
      paymentID: doc.id,
      bookingID: data['bookingID'] ?? '',
      custID: data['custID'],
      paymentDate: (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      paymentStatus: data['paymentStatus'] ?? 'Unpaid',
      referenceNumber: data['referenceNumber'] ?? '',
      customerName: data['customerName'] ?? '',
      isSimulated: data['isSimulated'] ?? false,
      recordedBy: data['recordedBy'] ?? 'admin',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentID': paymentID,
      'bookingID': bookingID,
      'custID': custID,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'referenceNumber': referenceNumber,
      'customerName': customerName,
      'isSimulated': isSimulated,
      'recordedBy': recordedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
