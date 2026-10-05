import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic/booking_rules.dart';
import '../models/add_on_model.dart';
import '../models/booking_model.dart';
import '../models/customer_model.dart';
import '../models/payment_model.dart';
import '../models/pet_model.dart';
import '../models/room_model.dart';
import '../models/room_type_model.dart';

/// Bookings and the booking lifecycle (spec §8.3, BOOK-*, WALK-*, ADMIN-002…004, QR-*).
///
/// Changes vs. the old implementation:
///  • no in-memory mock list and no fake booking IDs when a write fails (BOOK-008);
///  • real customer / pet / room are stored (fixes the hardcoded CUST-001 etc.);
///  • capacity-based availability check (Q-06) using room_reservations;
///  • status changes run in a transaction and follow the allowed transitions;
///  • room "Occupied" status is no longer written — occupancy is computed;
///  • no client-side /mail writes (duplicate / wrongly-addressed emails, ISS-11).
///    The Cloud Function sends the approval email (Q-08).
class BookingService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _res => _db.collection('room_reservations');

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// Admin only (security rules).
  Stream<List<BookingModel>> streamAll() => _col.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(BookingModel.fromFirestore).toList());

  /// BOOK-009: only the signed-in customer's own bookings.
  Stream<List<BookingModel>> streamForCustomer(String cusID) => _col.where('custID', isEqualTo: cusID).snapshots().map((s) {
    final list = s.docs.map(BookingModel.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });

  Stream<BookingModel?> streamBooking(String id) => _col.doc(id).snapshots().map((d) => d.exists ? BookingModel.fromFirestore(d) : null);

  Future<BookingModel?> getBooking(String id) async {
    final d = await _col.doc(id).get();
    return d.exists ? BookingModel.fromFirestore(d) : null;
  }

  // ------------------------------------------------------------------
  // Creation (BOOK-007, WALK-003)
  // ------------------------------------------------------------------

  /// Creates a booking after re-checking capacity for the room and dates.
  ///
  /// * Customer bookings start as `pending`; walk-ins (admin) start as
  ///   `approved` (Q-05).
  /// * Q-07: the simulated e-wallet also records a "Paid" payment (clearly
  ///   marked `isSimulated`); on-site cash records nothing, so the booking
  ///   shows as Unpaid until the admin records the payment.
  Future<String> createBooking({
    required CustomerModel customer,
    required PetModel pet,
    required RoomModel room,
    required RoomTypeModel roomType,
    required DateTime checkIn,
    required DateTime checkOut,
    required String timeSlot,
    required List<SelectedAddOn> addOns,
    required String paymentMethod,
    bool walkIn = false,
  }) async {
    // Customers can book only pets whose vaccination file the admin validated (walk-ins are handled by the admin at the desk).
    if (!walkIn && pet.bookingBlockReason != null) throw Exception(pet.bookingBlockReason);
    final dateError = validateStayDates(checkIn, checkOut);
    if (dateError != null) throw Exception(dateError);
    if (!RoomStatus.isBookable(room.status)) throw Exception('Room ${room.roomNum} is under maintenance.');

    final nights = nightsBetween(checkIn, checkOut);
    final total = calculateBookingTotal(pricePerNight: roomType.pricePerNight, nights: nights, addOns: addOns.map((a) => a.line));

    final ref = _col.doc();
    final booking = BookingModel(
      bookingID: ref.id,
      custID: customer.cusID,
      petID: pet.petID,
      roomID: room.roomID,
      checkInDate: dateOnly(checkIn),
      checkOutDate: dateOnly(checkOut),
      checkInTimeSlot: timeSlot,
      totalAmount: total,
      status: walkIn ? BookingStatus.approved : BookingStatus.pending,
      selectedAddOns: addOns,
      customerName: customer.fullName,
      customerEmail: customer.email,
      customerPhone: customer.phoneNum,
      petName: pet.petName,
      petType: pet.petType,
      roomNum: room.roomNum,
      roomTypeID: roomType.roomTypeID,
      roomTypeName: roomType.typeName,
      pricePerNight: roomType.pricePerNight,
      source: walkIn ? 'walk_in' : 'app',
      paymentMethod: paymentMethod,
    );

    // Capacity check and save happen together (Q-06). Every booking for a
    // room reads and bumps that room's lock document inside the transaction,
    // so two customers confirming the last slot at the same moment cannot
    // both succeed: Firestore retries the later one, which then sees the
    // first booking and is refused.
    final lockRef = _db.collection('room_locks').doc(room.roomID);
    final payRef = _db.collection('payments').doc();
    await _db.runTransaction((tx) async {
      final lock = await tx.get(lockRef);
      final reservations = await _res.where('roomID', isEqualTo: room.roomID).get();
      final stays = reservations.docs.map((d) => RoomReservation.fromFirestore(d).stay);
      final left = remainingSlots(capacity: roomType.maxCapacity, stays: stays, checkIn: checkIn, checkOut: checkOut);
      if (left <= 0) {
        throw Exception('Room ${room.roomNum} is fully booked for those dates. Please choose other dates or another room.');
      }
      final version = (lock.data()?['version'] as num?)?.toInt() ?? 0;
      tx.set(lockRef, {'version': version + 1, 'updatedAt': FieldValue.serverTimestamp()});
      tx.set(ref, {...booking.toMap(), 'createdAt': FieldValue.serverTimestamp(), if (walkIn) 'approvedAt': FieldValue.serverTimestamp()});
      tx.set(_res.doc(ref.id), RoomReservation.mapFor(booking));
      if (paymentMethod == PaymentMethods.eWalletSimulated) {
        tx.set(
          payRef,
          PaymentModel(
            paymentID: payRef.id,
            bookingID: ref.id,
            custID: customer.cusID,
            amount: total,
            paymentMethod: PaymentMethods.eWalletSimulated,
            paymentStatus: PaymentStatus.paid,
            referenceNumber: newPaymentReference(),
            customerName: customer.fullName,
            isSimulated: true,
            recordedBy: walkIn ? 'admin' : 'customer',
          ).toMap(),
        );
      }
    });
    return ref.id;
  }

  static String newPaymentReference() => 'PAY-${DateTime.now().year}-${100000 + Random().nextInt(900000)}';

  // ------------------------------------------------------------------
  // Status transitions (spec §8.3)
  // ------------------------------------------------------------------

  /// ADMIN-003: approve, re-checking capacity (in case of simultaneous requests).
  Future<void> approve(BookingModel b) async {
    final type = await _db.collection('room_types').doc(b.roomTypeID).get();
    final capacity = (type.data()?['maxCapacity'] as num?)?.toInt();
    if (capacity != null) {
      final res = await _res.where('roomID', isEqualTo: b.roomID).get();
      final others = res.docs.where((d) => d.id != b.bookingID).map((d) => RoomReservation.fromFirestore(d).stay);
      if (remainingSlots(capacity: capacity, stays: others, checkIn: b.checkInDate, checkOut: b.checkOutDate) <= 0) {
        throw Exception('Room ${b.roomNum} is already full for these dates. Reject this request or move it to another room.');
      }
    }
    await _transition(b.bookingID, BookingStatus.approved, extra: {'approvedAt': FieldValue.serverTimestamp()});
  }

  /// ADMIN-004
  Future<void> reject(String bookingID, {String reason = ''}) =>
      _transition(bookingID, BookingStatus.rejected, extra: {'rejectedAt': FieldValue.serverTimestamp(), if (reason.isNotEmpty) 'rejectionReason': reason});

  /// BOOK-011 / Q-15 — customer cancel (pending or approved, before check-in date).
  Future<void> customerCancel(BookingModel b) async {
    if (!canCustomerCancel(b.status, b.checkInDate)) {
      throw Exception('This booking can no longer be cancelled in the app. Please contact the hotel.');
    }
    await _transition(b.bookingID, BookingStatus.cancelled, extra: {'cancelledAt': FieldValue.serverTimestamp(), 'cancelledBy': 'customer'});
  }

  /// Admin cancel (any pending/approved booking).
  Future<void> adminCancel(String bookingID) =>
      _transition(bookingID, BookingStatus.cancelled, extra: {'cancelledAt': FieldValue.serverTimestamp(), 'cancelledBy': 'admin'});

  Future<void> _transition(String bookingID, String to, {Map<String, dynamic> extra = const {}}) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(_col.doc(bookingID));
      if (!snap.exists) throw Exception('This booking no longer exists.');
      final from = BookingStatus.normalize(snap.data()?['status'] ?? '');
      if (!isTransitionAllowed(from, to)) {
        throw Exception('A $from booking cannot be changed to ${to.replaceAll('_', ' ')}.');
      }
      tx.update(snap.reference, {'status': to, ...extra});
      tx.set(_res.doc(bookingID), {'status': to}, SetOptions(merge: true));
    });
  }

  // ------------------------------------------------------------------
  // QR check-in / check-out (QR-002 … QR-005)
  // ------------------------------------------------------------------

  /// Validates the scanned pass against the stored booking inside a
  /// transaction, so two scans at the same moment cannot both succeed.
  Future<QrScanResult> processScan(QrPayload payload) async {
    return _db.runTransaction<QrScanResult>((tx) async {
      final snap = await tx.get(_col.doc(payload.bookingID));
      if (!snap.exists) {
        return QrScanResult(null, const QrDecision.deny('No booking matches this pass.'));
      }
      final b = BookingModel.fromFirestore(snap);
      final decision = evaluateQrScan(action: payload.action, status: b.status, checkIn: b.checkInDate, checkOut: b.checkOutDate);
      if (decision.allowed && decision.newStatus != null) {
        final field = decision.newStatus == BookingStatus.checkedIn ? 'checkedInAt' : 'checkedOutAt';
        tx.update(snap.reference, {'status': decision.newStatus, field: FieldValue.serverTimestamp()});
        tx.set(_res.doc(b.bookingID), {'status': decision.newStatus}, SetOptions(merge: true));
        return QrScanResult(b.copyWith(status: decision.newStatus), decision);
      }
      return QrScanResult(b, decision);
    });
  }
}

class QrScanResult {
  final BookingModel? booking;
  final QrDecision decision;
  QrScanResult(this.booking, this.decision);
}
