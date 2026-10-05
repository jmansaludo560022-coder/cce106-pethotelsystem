import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/models/booking_model.dart';
import 'package:flutter_pethotelbooking/models/user_model.dart';

void main() {
  group('CCE 106 - UserRole & Role-Based Access Scope', () {
    test('UserRole enum contains strictly admin and customer', () {
      expect(UserRole.values, containsAll([UserRole.admin, UserRole.customer]));
      expect(UserRole.values.length, 2);

      // Verify mapping
      expect(UserModel.roleFromString('admin'), UserRole.admin);
      expect(UserModel.roleFromString('customer'), UserRole.customer);
      expect(UserModel.roleFromString('unknown_staff'), UserRole.customer); // Safe default

      expect(UserModel.roleToString(UserRole.admin), 'admin');
      expect(UserModel.roleToString(UserRole.customer), 'customer');
    });
  });

  group('CCE 106 - Booking Lifecycle State Machine', () {
    final baseBooking = BookingModel(
      bookingID: 'BK-DVO-001',
      custID: 'CUST-DVO-101',
      petID: 'PET-DVO-201',
      roomID: 'ROOM-101',
      checkInDate: DateTime(2026, 10, 1),
      checkOutDate: DateTime(2026, 10, 4),
      totalAmount: 1350.0,
      status: 'pending',
    );

    test('Initial submission status is strictly pending and QR pass is locked', () {
      expect(baseBooking.isPending, isTrue);
      expect(baseBooking.isApproved, isFalse);
      expect(baseBooking.isCheckedIn, isFalse);
      expect(baseBooking.isCheckedOut, isFalse);
      expect(baseBooking.isQrPassUnlocked, isFalse); // LOCKED!
      expect(baseBooking.displayStatus, 'Pending Approval');
      expect(baseBooking.nightsCount, 3);
    });

    test('Admin approval transitions to approved and UNLOCKS Digital QR Pass', () {
      final approvedBooking = baseBooking.copyWith(status: 'approved');
      expect(approvedBooking.isPending, isFalse);
      expect(approvedBooking.isApproved, isTrue);
      expect(approvedBooking.isCheckedIn, isFalse);
      expect(approvedBooking.isQrPassUnlocked, isTrue); // UNLOCKED!
      expect(approvedBooking.displayStatus, 'Approved');
    });

    test('Admin QR scanner check-in transitions to checked_in with pass still accessible', () {
      final checkedInBooking = baseBooking.copyWith(status: 'checked_in');
      expect(checkedInBooking.isCheckedIn, isTrue);
      expect(checkedInBooking.isApproved, isFalse);
      expect(checkedInBooking.isQrPassUnlocked, isTrue); // STILL ACCESSIBLE
      expect(checkedInBooking.displayStatus, 'Checked In');
    });

    test('Admin QR scanner check-out transitions to checked_out and locks pass', () {
      final checkedOutBooking = baseBooking.copyWith(status: 'checked_out');
      expect(checkedOutBooking.isCheckedOut, isTrue);
      expect(checkedOutBooking.isQrPassUnlocked, isFalse); // LOCKED after stay
      expect(checkedOutBooking.displayStatus, 'Checked Out');
    });

    test('Admin rejection transitions to rejected and locks pass', () {
      final rejectedBooking = baseBooking.copyWith(status: 'rejected');
      expect(rejectedBooking.isRejected, isTrue);
      expect(rejectedBooking.isQrPassUnlocked, isFalse);
      expect(rejectedBooking.displayStatus, 'Rejected');
    });
  });
}
