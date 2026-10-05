import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/models/review_model.dart';
import 'package:flutter_pethotelbooking/services/review_service.dart';

void main() {
  group('ReviewModel Unit Tests', () {
    test('Should correctly instantiate and convert ReviewModel to/from Map', () {
      final now = DateTime.now();
      final review = ReviewModel(
        reviewID: 'rev_123',
        custID: 'cust_456',
        custName: 'John Doe',
        petName: 'Rocky',
        roomTypeName: 'Deluxe Suite',
        rating: 5.0,
        title: 'Great Stay',
        comment: 'My dog was well taken care of!',
        status: 'Approved',
        createdAt: now,
      );

      final map = review.toMap();
      expect(map['reviewID'], 'rev_123');
      expect(map['custID'], 'cust_456');
      expect(map['custName'], 'John Doe');
      expect(map['petName'], 'Rocky');
      expect(map['roomTypeName'], 'Deluxe Suite');
      expect(map['rating'], 5.0);
      expect(map['title'], 'Great Stay');
      expect(map['comment'], 'My dog was well taken care of!');
      expect(map['status'], 'Approved');

      final copied = review.copyWith(comment: 'Updated comment', rating: 4);
      expect(copied.comment, 'Updated comment');
      expect(copied.rating, 4);
      expect(copied.custName, 'John Doe');
    });
  });

  group('ReviewService', () {
    // The old tests exercised a built-in in-memory "demo review" fallback.
    // That fallback was removed on purpose (spec REV-003 / DATA-003: no fake
    // reviews in production). The service now accesses Firestore lazily, so it
    // can be constructed without Firebase — this was the cause of the 4 old
    // failing tests ("No Firebase App '[DEFAULT]' has been created").
    test('can be constructed without initialising Firebase', () {
      expect(ReviewService.new, returnsNormally);
    });
  });
}
