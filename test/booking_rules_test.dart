import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/logic/booking_rules.dart';
import 'package:flutter_pethotelbooking/core/utils/validators.dart';

/// Unit tests for the business rules (master spec §8, Section 12 decisions).
void main() {
  final d = DateTime.new;

  group('Pricing (BOOK-005, Q-14)', () {
    test('room × nights + add-on price × quantity', () {
      final total = calculateBookingTotal(pricePerNight: 450, nights: 3, addOns: const [AddOnLine(350, 1), AddOnLine(100, 2)]);
      expect(total, 450 * 3 + 350 + 200);
    });
    test('nights are counted by calendar date, minimum 1', () {
      expect(nightsBetween(d(2026, 10, 1, 18), d(2026, 10, 4, 9)), 3);
      expect(nightsBetween(d(2026, 10, 1), d(2026, 10, 1)), 1);
    });
  });

  group('Stay dates (spec §8.4)', () {
    final today = d(2026, 9, 30);
    test('past check-in is rejected', () {
      expect(validateStayDates(d(2026, 9, 29), d(2026, 10, 2), today: today), isNotNull);
    });
    test('check-out must be after check-in', () {
      expect(validateStayDates(d(2026, 10, 2), d(2026, 10, 2), today: today), isNotNull);
    });
    test('valid range passes', () {
      expect(validateStayDates(d(2026, 9, 30), d(2026, 10, 1), today: today), isNull);
    });
  });

  group('Capacity-based availability (Q-06)', () {
    final stays = [
      StayRange(d(2026, 10, 1), d(2026, 10, 4), 'approved'),
      StayRange(d(2026, 10, 3), d(2026, 10, 5), 'pending'), // pending holds a slot
      StayRange(d(2026, 10, 1), d(2026, 10, 9), 'cancelled'), // ignored
      StayRange(d(2026, 10, 1), d(2026, 10, 9), 'checked_out'), // ignored
    ];
    test('overlapping active stays reduce remaining slots', () {
      expect(remainingSlots(capacity: 2, stays: stays, checkIn: d(2026, 10, 3), checkOut: d(2026, 10, 4)), 0);
      expect(remainingSlots(capacity: 3, stays: stays, checkIn: d(2026, 10, 3), checkOut: d(2026, 10, 4)), 1);
    });
    test('check-out day is free for a new check-in (half-open ranges)', () {
      expect(remainingSlots(capacity: 1, stays: stays, checkIn: d(2026, 10, 5), checkOut: d(2026, 10, 6)), 1);
    });
    test('never negative', () {
      expect(remainingSlots(capacity: 1, stays: stays, checkIn: d(2026, 10, 1), checkOut: d(2026, 10, 9)), 0);
    });
    test('maintenance rooms are not bookable', () {
      expect(RoomStatus.isBookable('Maintenance'), isFalse);
      expect(RoomStatus.isBookable('Occupied'), isTrue); // legacy value, occupancy is computed
    });
  });

  group('Status transitions (spec §8.3)', () {
    test('allowed', () {
      expect(isTransitionAllowed('pending', 'approved'), isTrue);
      expect(isTransitionAllowed('Pending', 'rejected'), isTrue);
      expect(isTransitionAllowed('approved', 'checked_in'), isTrue);
      expect(isTransitionAllowed('checked_in', 'checked_out'), isTrue);
    });
    test('not allowed', () {
      expect(isTransitionAllowed('pending', 'checked_in'), isFalse);
      expect(isTransitionAllowed('checked_out', 'checked_in'), isFalse);
      expect(isTransitionAllowed('cancelled', 'approved'), isFalse);
      expect(isTransitionAllowed('checked_in', 'cancelled'), isFalse);
    });
  });

  group('Customer cancellation (Q-15)', () {
    final today = d(2026, 9, 30);
    test('pending or approved before check-in date', () {
      expect(canCustomerCancel('pending', d(2026, 10, 1), today: today), isTrue);
      expect(canCustomerCancel('approved', d(2026, 10, 1), today: today), isTrue);
    });
    test('not on/after check-in date or in other states', () {
      expect(canCustomerCancel('approved', d(2026, 9, 30), today: today), isFalse);
      expect(canCustomerCancel('checked_in', d(2026, 10, 5), today: today), isFalse);
      expect(canCustomerCancel('rejected', d(2026, 10, 5), today: today), isFalse);
    });
  });

  group('Payments (PAY-003, spec §8.4)', () {
    test('status from total paid', () {
      expect(computePaymentStatus(totalPaid: 0, bookingTotal: 1000), PaymentStatus.unpaid);
      expect(computePaymentStatus(totalPaid: 400, bookingTotal: 1000), PaymentStatus.partial);
      expect(computePaymentStatus(totalPaid: 1000, bookingTotal: 1000), PaymentStatus.paid);
    });
    test('amount validation', () {
      expect(validatePaymentAmount(0, balance: 500), isNotNull);
      expect(validatePaymentAmount(-5, balance: 500), isNotNull);
      expect(validatePaymentAmount(600, balance: 500), isNotNull);
      expect(validatePaymentAmount(500, balance: 500), isNull);
    });
  });

  group('QR pass (QR-001 … QR-005, Q-16)', () {
    test('payload contains only the booking reference and action', () {
      final p = QrPayload('abc123', QrAction.checkIn);
      expect(p.encode(), 'PETHOTEL:CHECKIN:abc123');
      final parsed = QrPayload.parse(p.encode())!;
      expect(parsed.bookingID, 'abc123');
      expect(parsed.action, QrAction.checkIn);
    });
    test('legacy payload with room ID still parses; junk is rejected', () {
      expect(QrPayload.parse('PETHOTEL:CHECKOUT:abc123:room_101')!.action, QrAction.checkOut);
      expect(QrPayload.parse('hello'), isNull);
      expect(QrPayload.parse('PETHOTEL:DANCE:abc'), isNull);
    });

    final inDate = d(2026, 10, 1);
    final outDate = d(2026, 10, 4);
    QrDecision scan(QrAction a, String s, DateTime now) => evaluateQrScan(action: a, status: s, checkIn: inDate, checkOut: outDate, now: now);

    test('check-in allowed for approved booking within the date window', () {
      expect(scan(QrAction.checkIn, 'approved', d(2026, 10, 1)).allowed, isTrue);
      expect(scan(QrAction.checkIn, 'approved', d(2026, 10, 4)).allowed, isTrue);
      expect(scan(QrAction.checkIn, 'approved', d(2026, 10, 1)).newStatus, BookingStatus.checkedIn);
    });
    test('check-in refused: too early, expired, pending, duplicate', () {
      expect(scan(QrAction.checkIn, 'approved', d(2026, 9, 30)).allowed, isFalse);
      expect(scan(QrAction.checkIn, 'approved', d(2026, 10, 5)).allowed, isFalse);
      expect(scan(QrAction.checkIn, 'pending', d(2026, 10, 1)).allowed, isFalse);
      expect(scan(QrAction.checkIn, 'checked_in', d(2026, 10, 2)).allowed, isFalse);
    });
    test('check-out only after check-in; re-scan does not repeat', () {
      expect(scan(QrAction.checkOut, 'checked_in', d(2026, 10, 4)).newStatus, BookingStatus.checkedOut);
      expect(scan(QrAction.checkOut, 'approved', d(2026, 10, 4)).allowed, isFalse);
      expect(scan(QrAction.checkOut, 'checked_out', d(2026, 10, 4)).allowed, isFalse);
    });
  });

  group('Validators', () {
    test('PH phone numbers', () {
      expect(Validators.phPhone('09171234567'), isNull);
      expect(Validators.phPhone('+63 917 123 4567'), isNull);
      expect(Validators.phPhone('12345'), isNotNull);
    });
    test('email and password', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });
    test('confirm password must match exactly', () {
      expect(Validators.confirmPassword('', 'secret1'), isNotNull);
      expect(Validators.confirmPassword('Secret1', 'secret1'), 'Passwords do not match.');
      expect(Validators.confirmPassword('secret1', 'secret1'), isNull);
    });
  });
}
