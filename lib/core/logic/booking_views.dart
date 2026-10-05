import '../../models/booking_model.dart';
import 'booking_rules.dart';

/// How the customer's bookings are grouped on Home and My Bookings
/// (Enhancement Spec §9.1, §9.2). Pure, so it is unit-tested.
class BookingViews {
  BookingViews._();

  /// Pending, confirmed or currently checked in.
  static bool isUpcoming(BookingModel b) => b.isPending || b.isApproved || b.isCheckedIn;

  static List<BookingModel> upcoming(Iterable<BookingModel> all) => _sorted(all.where(isUpcoming));
  static List<BookingModel> completed(Iterable<BookingModel> all) => all.where((b) => b.isCheckedOut).toList();
  static List<BookingModel> cancelled(Iterable<BookingModel> all) => all.where((b) => b.isCancelled || b.isRejected).toList();

  /// The stay to feature on Home: a current stay first, else the soonest
  /// upcoming one. Null when there is nothing upcoming.
  static BookingModel? nextStay(Iterable<BookingModel> all) {
    final list = upcoming(all);
    return list.where((b) => b.isCheckedIn).firstOrNull ?? list.firstOrNull;
  }

  /// "Today", "Tomorrow", "In 3 days"; "Staying now" while checked in.
  static String countdown(BookingModel b, DateTime now) {
    if (b.isCheckedIn) return 'Staying now';
    final days = dateOnly(b.checkInDate).difference(dateOnly(now)).inDays;
    if (days < 0) return 'Check-in passed';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  static List<BookingModel> _sorted(Iterable<BookingModel> list) => list.toList()..sort((a, b) => a.checkInDate.compareTo(b.checkInDate));
}
