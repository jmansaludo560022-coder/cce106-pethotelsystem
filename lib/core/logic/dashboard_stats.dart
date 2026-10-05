import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import 'booking_rules.dart';

/// Every number on the Admin Dashboard, computed from real bookings and
/// payments (nothing hard-coded). Pure, so it is unit-tested.
class DashboardStats {
  /// Needs attention
  final int pending;
  final int checkInsToday; // approved, check-in date is today
  final int checkOutsToday; // checked in, check-out date is today

  /// Operations
  final int activeBookings; // approved + checked in
  final int petsInHouse; // checked in
  final int occupiedRooms; // rooms with at least one checked-in pet
  final int activeCustomers; // customers with an approved or checked-in booking

  /// Revenue (last 7 days, oldest first; today last)
  final List<DateTime> days;
  final List<double> perDay;
  final double week;
  final double? changePercent; // vs the 7 days before; null when no data

  const DashboardStats._({
    required this.pending,
    required this.checkInsToday,
    required this.checkOutsToday,
    required this.activeBookings,
    required this.petsInHouse,
    required this.occupiedRooms,
    required this.activeCustomers,
    required this.days,
    required this.perDay,
    required this.week,
    required this.changePercent,
  });

  int get needsAttention => pending + checkInsToday + checkOutsToday;

  factory DashboardStats.from(List<BookingModel> bookings, List<PaymentModel> payments, DateTime now) {
    final today = dateOnly(now);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final perDay = [for (final d in days) payments.where((p) => dateOnly(p.paymentDate) == d).fold<double>(0, (s, p) => s + p.amount)];
    final week = perDay.fold<double>(0, (s, v) => s + v);
    final prevStart = today.subtract(const Duration(days: 13));
    final prevWeek = payments
        .where((p) => !dateOnly(p.paymentDate).isBefore(prevStart) && dateOnly(p.paymentDate).isBefore(days.first))
        .fold<double>(0, (s, p) => s + p.amount);
    return DashboardStats._(
      pending: bookings.where((b) => b.isPending).length,
      checkInsToday: bookings.where((b) => b.isApproved && dateOnly(b.checkInDate) == today).length,
      checkOutsToday: bookings.where((b) => b.isCheckedIn && dateOnly(b.checkOutDate) == today).length,
      activeBookings: bookings.where((b) => b.isApproved || b.isCheckedIn).length,
      petsInHouse: bookings.where((b) => b.isCheckedIn).length,
      occupiedRooms: bookings.where((b) => b.isCheckedIn).map((b) => b.roomID).toSet().length,
      activeCustomers: bookings.where((b) => b.isApproved || b.isCheckedIn).map((b) => b.custID).toSet().length,
      days: days,
      perDay: perDay,
      week: week,
      changePercent: prevWeek > 0 ? (week - prevWeek) / prevWeek * 100 : null,
    );
  }
}
