import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/review_model.dart';

/// Reviews (REV-001 … REV-004).
///
/// * No built-in demo reviews any more (REV-003 / ISS-28).
/// * One review per booking: the review document ID is the booking ID (Q-12).
/// * Published immediately; the admin can only view and delete (REV-004).
/// * Firestore is accessed lazily, so creating this service no longer crashes
///   when Firebase is not initialised (the old cause of 4 failing tests).
class ReviewService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('reviews');

  Stream<List<ReviewModel>> streamAll() =>
      _col.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(ReviewModel.fromFirestore).toList());

  Stream<List<ReviewModel>> streamForCustomer(String cusID) => _col.where('custID', isEqualTo: cusID).snapshots().map((s) {
        final list = s.docs.map(ReviewModel.fromFirestore).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// REV-001/REV-002: only for the customer's own checked-out booking. The
  /// customer name comes from the profile — it is not typed in.
  Future<void> submit({required BookingModel booking, required String customerName, required double rating, required String comment, ReviewModel? existing}) async {
    if (!booking.isCheckedOut) throw Exception('You can review a stay after check-out.');
    if (rating < 1 || rating > 5) throw Exception('Please choose a rating from 1 to 5 stars.');
    if (comment.trim().isEmpty) throw Exception('Please write a short review.');
    final ref = _col.doc(booking.bookingID);
    if (existing != null) {
      await ref.update({'rating': rating, 'comment': comment.trim()});
      return;
    }
    await ref.set(ReviewModel(
      reviewID: booking.bookingID,
      custID: booking.custID,
      custName: customerName,
      petName: booking.petName,
      bookingID: booking.bookingID,
      roomTypeName: booking.roomTypeName,
      rating: rating,
      title: '',
      comment: comment.trim(),
      status: 'Approved',
    ).toMap());
  }

  /// Admin only (REV-004).
  Future<void> delete(String reviewID) => _col.doc(reviewID).delete();
}
