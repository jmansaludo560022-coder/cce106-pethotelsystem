import 'package:intl/intl.dart';

/// Shared display formatting so every screen shows money and dates the same way.
class Fmt {
  static final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  static final _pesoWhole = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

  static String peso(num value) => _peso.format(value);

  /// Whole pesos when there are no centavos (e.g. ₱450), otherwise 2 decimals.
  static String pesoShort(num value) => value == value.roundToDouble() ? _pesoWhole.format(value) : _peso.format(value);

  static String date(DateTime d) => DateFormat('MMM d, yyyy').format(d);
  static String dateShort(DateTime d) => DateFormat('MMM d').format(d);
  static String dateTime(DateTime d) => DateFormat('MMM d, yyyy · h:mm a').format(d);
  static String weekday(DateTime d) => DateFormat('EEE').format(d);

  static String range(DateTime a, DateTime b) =>
      a.year == b.year ? '${dateShort(a)} – ${date(b)}' : '${date(a)} – ${date(b)}';

  /// Short, readable booking reference derived from the Firestore ID.
  static String ref(String id) {
    if (id.isEmpty) return '—';
    final s = id.length > 8 ? id.substring(0, 8) : id;
    return s.toUpperCase();
  }

  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
}
