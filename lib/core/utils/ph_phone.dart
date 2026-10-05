import 'package:flutter/services.dart';

/// Philippine mobile numbers (spec §10.1).
///
/// * Stored in E.164: `+639171234567`.
/// * Displayed as `+63 917 123 4567`.
/// * Any common input is accepted and normalized: `09171234567`,
///   `639171234567`, `+639171234567`, `9171234567`, with spaces, dashes,
///   dots or brackets. The common slip `+63 0917…` (country code plus the
///   trunk 0) is accepted too.
/// * Rejected: letters or other symbols, a repeated country code
///   (`+63 63 917…`), wrong lengths, and prefixes other than 9.
/// * Older records saved as `09…` keep working: they are normalized on read.
class PhPhone {
  static final RegExp valid = RegExp(r'^\+639\d{9}$');
  static final RegExp _allowedChars = RegExp(r'^\+?[\d\s\-.()]+$');
  static const String errorText = 'Enter a valid PH mobile number (e.g. 917 123 4567).';

  /// Returns the E.164 form, or null when the input cannot be a PH mobile number.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    // Only digits and common separators; "+" only at the very start.
    if (!_allowedChars.hasMatch(t)) return null;
    final e164 = '+63${localPart(t.replaceAll(RegExp(r'\D'), ''))}';
    return valid.hasMatch(e164) ? e164 : null;
  }

  /// Reduces digits to the local part: drops one leading country code "63"
  /// (only when more than 10 digits remain) and then one trunk "0".
  static String localPart(String digits) {
    var d = digits;
    if (d.length > 10 && d.startsWith('63')) d = d.substring(2);
    if (d.length > 10 && d.startsWith('0')) d = d.substring(1);
    return d;
  }

  /// `+63 917 123 4567` for valid numbers; anything else is shown unchanged.
  static String display(String? raw) {
    final n = normalize(raw);
    if (n == null) return (raw ?? '').trim();
    final local = n.substring(3); // 9171234567
    return '+63 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
  }

  /// The 10 local digits (`9171234567`) used to pre-fill the input field.
  static String localDigits(String? raw) {
    final n = normalize(raw);
    if (n != null) return n.substring(3);
    final d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  /// Form validator for the 10 digits typed after the fixed +63 prefix.
  static String? validateLocal(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return 'Mobile number is required.';
    return normalize('+63$d') == null ? errorText : null;
  }

  /// Every stored form an existing record might use, for duplicate checks.
  static List<String> storedVariants(String e164) {
    final local = e164.substring(3);
    return [e164, '0$local', '63$local', local];
  }
}

/// Formats the local part as `9XX XXX XXXX` while typing, max 10 digits.
/// Pasted numbers in any form (09…, 63…, +63…, +63 0…) are reduced to the 10 digits.
class PhLocalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = PhPhone.localPart(newValue.text.replaceAll(RegExp(r'\D'), ''));
    if (d.length > 10) d = d.substring(0, 10);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6) b.write(' ');
      b.write(d[i]);
    }
    final text = b.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
