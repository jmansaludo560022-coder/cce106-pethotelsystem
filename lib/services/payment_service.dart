import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic/booking_rules.dart';
import '../models/booking_model.dart';
import '../models/payment_model.dart';
import 'booking_service.dart';

/// Payments (PAY-001 … PAY-006). No real payment provider is integrated; the
/// e-wallet option is a simulation and is labelled as such (Q-07).
class PaymentService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('payments');

  /// Admin only.
  Stream<List<PaymentModel>> streamAll() =>
      _col.orderBy('paymentDate', descending: true).snapshots().map((s) => s.docs.map(PaymentModel.fromFirestore).toList());

  /// Customer's own payments.
  Stream<List<PaymentModel>> streamForCustomer(String cusID) => _col.where('custID', isEqualTo: cusID).snapshots().map((s) {
        final list = s.docs.map(PaymentModel.fromFirestore).toList();
        list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
        return list;
      });

  /// Records a payment and stores the resulting (cumulative) status.
  /// Validates amount > 0 and ≤ remaining balance (spec §8.4).
  Future<void> recordPayment({
    required BookingModel booking,
    required double amount,
    required String method,
    DateTime? date,
    bool isSimulated = false,
    String recordedBy = 'admin',
  }) async {
    final existing = await _col.where('custID', isEqualTo: booking.custID).where('bookingID', isEqualTo: booking.bookingID).get();
    final paid = existing.docs.fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
    final balance = booking.totalAmount - paid;
    final err = validatePaymentAmount(amount, balance: balance);
    if (err != null) throw Exception(err);
    final ref = _col.doc();
    await ref.set(PaymentModel(
      paymentID: ref.id,
      bookingID: booking.bookingID,
      custID: booking.custID,
      paymentDate: date ?? DateTime.now(),
      amount: amount,
      paymentMethod: method,
      paymentStatus: computePaymentStatus(totalPaid: paid + amount, bookingTotal: booking.totalAmount),
      referenceNumber: BookingService.newPaymentReference(),
      customerName: booking.customerName,
      isSimulated: isSimulated,
      recordedBy: recordedBy,
    ).toMap());
  }

  /// PAY-005: edit date / method / amount; the status is recalculated.
  Future<void> updatePayment({
    required PaymentModel payment,
    required BookingModel booking,
    required List<PaymentModel> bookingPayments,
    required double amount,
    required String method,
    required DateTime date,
  }) async {
    final others = bookingPayments.where((p) => p.paymentID != payment.paymentID).fold<double>(0, (s, p) => s + p.amount);
    final err = validatePaymentAmount(amount, balance: booking.totalAmount - others);
    if (err != null) throw Exception(err);
    await _col.doc(payment.paymentID).update({
      'amount': amount,
      'paymentMethod': method,
      'paymentDate': Timestamp.fromDate(date),
      'paymentStatus': computePaymentStatus(totalPaid: others + amount, bookingTotal: booking.totalAmount),
    });
  }
}

/// Financial summary of one booking (payment details screen, ledger).
class BookingPaymentSummary {
  final BookingModel booking;
  final List<PaymentModel> payments;
  BookingPaymentSummary(this.booking, this.payments);

  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get balance => (booking.totalAmount - paid).clamp(0, double.infinity);
  String get status => computePaymentStatus(totalPaid: paid, bookingTotal: booking.totalAmount);
  double get progress => booking.totalAmount <= 0 ? 1 : (paid / booking.totalAmount).clamp(0, 1);

  static Map<String, List<PaymentModel>> groupByBooking(List<PaymentModel> payments) {
    final m = <String, List<PaymentModel>>{};
    for (final p in payments) {
      m.putIfAbsent(p.bookingID, () => []).add(p);
    }
    return m;
  }
}
