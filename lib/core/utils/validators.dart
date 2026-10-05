import 'ph_phone.dart';

/// Form validators (master spec §8.4). Each returns an error message or null.
class Validators {
  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required.' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address.';
  }

  /// Minimum 6 characters (SRC-C p.2 / Firebase Auth minimum).
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  /// Confirm-password field: must match the password exactly.
  static String? confirmPassword(String? v, String password) {
    if (v == null || v.isEmpty) return 'Please re-enter your password.';
    if (v != password) return 'Passwords do not match.';
    return null;
  }

  /// Philippine mobile number in any common form (spec §10.1, see [PhPhone]).
  static String? phPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required.';
    return PhPhone.normalize(v) == null ? PhPhone.errorText : null;
  }

  static String? positiveNumber(String? v, [String field = 'Value']) {
    final n = double.tryParse((v ?? '').replaceAll(',', '').trim());
    if (n == null) return '$field must be a number.';
    if (n <= 0) return '$field must be greater than zero.';
    return null;
  }

  static String? positiveInt(String? v, [String field = 'Value']) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return '$field must be a whole number.';
    if (n < 1) return '$field must be at least 1.';
    return null;
  }

  static String normalizeEmail(String v) => v.trim().toLowerCase();
  static String normalizePhone(String v) => v.replaceAll(RegExp(r'[\s-]'), '');
}
