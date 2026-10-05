/// Pure business rules (no Firebase) so they can be unit-tested.
///
/// Every rule references the master specification section / decision it
/// implements. Owner decisions (Sept 30, 2026): Q-06 capacity-based slots,
/// Q-07 payment rules, Q-14 add-on pricing, Q-15 cancellation, Q-16 QR window.
library;

/// Canonical booking statuses (DATA-002: one lower-case spelling everywhere).
class BookingStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const checkedIn = 'checked_in';
  static const checkedOut = 'checked_out';

  /// Statuses that occupy room capacity (Q-06: pending holds a slot until it
  /// is rejected or cancelled).
  static const active = [pending, approved, checkedIn];

  static String normalize(String raw) {
    final s = raw.toLowerCase().trim().replaceAll(' ', '_');
    return s;
  }
}

/// Payment statuses (PAY-003).
class PaymentStatus {
  static const paid = 'Paid';
  static const partial = 'Partial';
  static const unpaid = 'Unpaid';
}

/// Payment methods offered to customers (PAY-001) and to the admin (PAY-004).
class PaymentMethods {
  static const eWalletSimulated = 'E-Wallet (Simulated)';
  static const onSiteCash = 'On-site Cash';
  static const adminMethods = ['Cash', 'GCash', 'Maya', 'Card', 'Bank Transfer'];
}

/// Arrival time slots (Q-17 kept; Figma booking step 2).
const List<String> kCheckInTimeSlots = [
  'Morning (10:00 AM - 12:00 PM)',
  'Afternoon (1:00 PM - 3:00 PM)',
  'Evening (4:00 PM - 6:00 PM)',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Number of nights, minimum 1.
int nightsBetween(DateTime checkIn, DateTime checkOut) {
  final n = dateOnly(checkOut).difference(dateOnly(checkIn)).inDays;
  return n <= 0 ? 1 : n;
}

/// Booking dates validation (spec §8.4). Returns an error message or null.
String? validateStayDates(DateTime? checkIn, DateTime? checkOut, {DateTime? today}) {
  if (checkIn == null || checkOut == null) return 'Please choose check-in and check-out dates.';
  final t = dateOnly(today ?? DateTime.now());
  if (dateOnly(checkIn).isBefore(t)) return 'Check-in date cannot be in the past.';
  if (!dateOnly(checkOut).isAfter(dateOnly(checkIn))) return 'Check-out must be at least one night after check-in.';
  return null;
}

/// An add-on line used for pricing.
/// How an add-on is charged (decision D6). Records saved before D6 have no
/// unit and are treated as [perStay] — the original Q-14 rule.
class AddOnUnits {
  static const String perStay = 'stay';
  static const String perDay = 'day';
  static const List<String> all = [perStay, perDay];

  static String normalize(String? unit) => unit == perDay ? perDay : perStay;
  static String label(String? unit) => normalize(unit) == perDay ? 'per day' : 'per stay';

  /// Days the price applies to: the number of nights for per-day add-ons
  /// (at least 1), otherwise 1.
  static int daysFor(String? unit, int nights) => normalize(unit) == perDay ? (nights < 1 ? 1 : nights) : 1;
}

class AddOnLine {
  final double price;
  final int quantity;

  /// 1 for per-stay add-ons; the number of nights for per-day add-ons.
  final int days;
  const AddOnLine(this.price, this.quantity, [this.days = 1]);
}

/// BOOK-005: total = price per night × nights + Σ(add-on price × quantity × days).
/// Q-14 / D6: per-stay add-ons use days = 1; per-day add-ons use the nights.
double calculateBookingTotal({
  required double pricePerNight,
  required int nights,
  Iterable<AddOnLine> addOns = const [],
}) {
  final room = pricePerNight * nights;
  final extras = addOns.fold<double>(0, (sum, a) => sum + a.price * a.quantity * a.days);
  return double.parse((room + extras).toStringAsFixed(2));
}

/// A stay occupying a room (from room_reservations).
class StayRange {
  final DateTime checkIn;
  final DateTime checkOut;
  final String status;
  const StayRange(this.checkIn, this.checkOut, this.status);
}

/// Half-open date overlap: [aIn, aOut) intersects [bIn, bOut).
bool rangesOverlap(DateTime aIn, DateTime aOut, DateTime bIn, DateTime bOut) {
  return dateOnly(aIn).isBefore(dateOnly(bOut)) && dateOnly(bIn).isBefore(dateOnly(aOut));
}

/// Q-06 (capacity-based): a room can host overlapping active stays up to the
/// room type's max capacity. Returns remaining slots for the requested range
/// (never negative). Counting every overlapping stay is intentionally
/// conservative so the hotel can never be over-booked.
int remainingSlots({
  required int capacity,
  required Iterable<StayRange> stays,
  required DateTime checkIn,
  required DateTime checkOut,
}) {
  final used = stays.where((s) =>
      BookingStatus.active.contains(BookingStatus.normalize(s.status)) &&
      rangesOverlap(s.checkIn, s.checkOut, checkIn, checkOut)).length;
  final left = capacity - used;
  return left < 0 ? 0 : left;
}

/// Room status values the admin can set. "Occupied" is no longer stored —
/// occupancy is computed from stays (legacy "Occupied" docs are treated as
/// bookable).
class RoomStatus {
  static const available = 'Available';
  static const maintenance = 'Maintenance';
  static const values = [available, maintenance];
  static bool isBookable(String status) => status.toLowerCase() != 'maintenance';
}

/// Q-15: a customer may cancel while pending or approved, before the check-in date.
bool canCustomerCancel(String status, DateTime checkIn, {DateTime? today}) {
  final s = BookingStatus.normalize(status);
  if (s != BookingStatus.pending && s != BookingStatus.approved) return false;
  return dateOnly(today ?? DateTime.now()).isBefore(dateOnly(checkIn));
}

/// Permitted booking status transitions (spec §8.3, BOOK-012).
const Map<String, List<String>> kAllowedTransitions = {
  BookingStatus.pending: [BookingStatus.approved, BookingStatus.rejected, BookingStatus.cancelled],
  BookingStatus.approved: [BookingStatus.checkedIn, BookingStatus.cancelled],
  BookingStatus.checkedIn: [BookingStatus.checkedOut],
  BookingStatus.rejected: [],
  BookingStatus.cancelled: [],
  BookingStatus.checkedOut: [],
};

bool isTransitionAllowed(String from, String to) =>
    kAllowedTransitions[BookingStatus.normalize(from)]?.contains(BookingStatus.normalize(to)) ?? false;

/// PAY-003: status is always calculated from the total paid.
String computePaymentStatus({required double totalPaid, required double bookingTotal}) {
  if (totalPaid <= 0) return PaymentStatus.unpaid;
  if (totalPaid + 0.009 >= bookingTotal) return PaymentStatus.paid;
  return PaymentStatus.partial;
}

/// Spec §8.4: amount > 0 and not more than the remaining balance.
String? validatePaymentAmount(double? amount, {required double balance}) {
  if (amount == null || amount <= 0) return 'Enter an amount greater than zero.';
  if (amount > balance + 0.009) return 'Amount is more than the remaining balance (₱${balance.toStringAsFixed(2)}).';
  return null;
}

// ------------------------------------------------------------------
// QR pass (QR-001 … QR-005)
// ------------------------------------------------------------------

enum QrAction { checkIn, checkOut }

class QrPayload {
  final String bookingID;
  final QrAction action;
  const QrPayload(this.bookingID, this.action);

  /// The QR only contains the booking reference and the action — no personal
  /// data. The scanner always re-validates against Firestore.
  String encode() => 'PETHOTEL:${action == QrAction.checkIn ? 'CHECKIN' : 'CHECKOUT'}:$bookingID';

  /// Accepts the current format and the legacy "PETHOTEL:ACTION:id:roomID".
  static QrPayload? parse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 3 || parts[0] != 'PETHOTEL') return null;
    final action = switch (parts[1]) {
      'CHECKIN' => QrAction.checkIn,
      'CHECKOUT' => QrAction.checkOut,
      _ => null,
    };
    if (action == null || parts[2].trim().isEmpty) return null;
    return QrPayload(parts[2].trim(), action);
  }
}

/// Result of validating a scan against the stored booking.
class QrDecision {
  final bool allowed;
  final String message;
  final String? newStatus;
  const QrDecision.allow(this.message, this.newStatus) : allowed = true;
  const QrDecision.deny(this.message)
      : allowed = false,
        newStatus = null;
}

/// QR-003/QR-004/QR-005 and Q-16: check-in allowed for an approved booking from
/// the check-in date through the check-out date (inclusive); check-out allowed
/// for a checked-in booking. Re-scans never repeat a transition.
QrDecision evaluateQrScan({
  required QrAction action,
  required String status,
  required DateTime checkIn,
  required DateTime checkOut,
  DateTime? now,
}) {
  final s = BookingStatus.normalize(status);
  final today = dateOnly(now ?? DateTime.now());
  if (action == QrAction.checkIn) {
    if (s == BookingStatus.checkedIn) return const QrDecision.deny('This pet is already checked in.');
    if (s == BookingStatus.checkedOut) return const QrDecision.deny('This booking is already checked out.');
    if (s == BookingStatus.pending) return const QrDecision.deny('This booking has not been approved yet.');
    if (s != BookingStatus.approved) return QrDecision.deny('Booking is $s — check-in is not allowed.');
    if (today.isBefore(dateOnly(checkIn))) return const QrDecision.deny('Too early: check-in opens on the check-in date.');
    if (today.isAfter(dateOnly(checkOut))) return const QrDecision.deny('This pass has expired (the stay has ended).');
    return const QrDecision.allow('Check-in confirmed.', BookingStatus.checkedIn);
  } else {
    if (s == BookingStatus.checkedOut) return const QrDecision.deny('This booking is already checked out.');
    if (s != BookingStatus.checkedIn) return const QrDecision.deny('Check-out requires the pet to be checked in first.');
    return const QrDecision.allow('Check-out confirmed.', BookingStatus.checkedOut);
  }
}
