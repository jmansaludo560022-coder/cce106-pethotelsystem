import 'package:flutter/material.dart';

/// Color tokens (Enhancement Spec §2 — "retro cartoon pet hotel"): warm cream
/// canvas, bold mustard, orange / teal / sky accents and thick ink outlines.
/// The 11 spec tokens are defined once below; every other name is a role
/// that points to one of them, so existing screens keep compiling.
///
/// Rules (§2): background is always warm cream; content sits on warm ivory
/// surface cards with a 1.5 px ink or line border — no pure white anywhere
/// (owner HCI requirement, 2026-10-03); text on mustard is ink; status is
/// never shown by color alone (badges always carry a label).
class AppColors {
  // ===== Spec §2 tokens =====
  static const Color cream = Color(0xFFFAF3E6); // App background (warm sand)
  static const Color ivory = Color(0xFFFFFCF5); // Cards, sheets, fields (warm, never pure white)
  static const Color surfaceWhite = ivory; // legacy name
  static const Color ink = Color(0xFF1E1B16); // Primary text, outlines, icons
  static const Color inkMuted = Color(0xFF6B6358); // Secondary text, hints
  static const Color line = Color(0xFFE9E1D2); // Borders, dividers
  static const Color mustard = Color(0xFFF5B21B); // Primary brand, main CTA, active nav
  static const Color mustardSoft = Color(0xFFFFE9B3); // Chips, selected backgrounds
  static const Color orange = Color(0xFFF2672A); // Secondary accent, badges
  static const Color teal = Color(0xFF179C7A); // Success, confirmed
  static const Color sky = Color(0xFF5AA9E6); // Info banners, links
  static const Color berry = Color(0xFFE5484D); // Errors, cancellations, destructive

  // Darker text shades of the accents, so small text on soft backgrounds
  // meets WCAG AA (4.5:1). Derived from the spec accents, not new hues.
  static const Color tealText = Color(0xFF0B6650);
  static const Color berryText = Color(0xFFB4232A);
  static const Color orangeText = Color(0xFFA8401A);
  static const Color skyText = Color(0xFF1C5A8C);
  static const Color mustardText = Color(0xFF7A5300);

  // Soft tints for badges / banners / category tiles.
  static const Color tealSoft = Color(0xFFDDF3EC);
  static const Color berrySoft = Color(0xFFFDE4E4);
  static const Color orangeSoft = Color(0xFFFDE5D9);
  static const Color skySoft = Color(0xFFE1EFFB);

  // ===== Roles (map onto the tokens above) =====
  static const Color primary = mustard;
  static const Color primaryLight = mustardSoft;
  static const Color primaryDark = mustardText;
  static const Color primaryContainer = mustardSoft;
  static const Color onPrimary = ink; // text on mustard is ink, never white

  static const Color onInk = surfaceWhite;
  static const Color secondary = ink;
  static const Color secondaryLight = inkMuted;
  static const Color secondaryDark = ink;
  static const Color secondaryContainer = line;

  static const Color background = cream;
  static const Color surface = surfaceWhite;
  static const Color surfaceVariant = Color(0xFFF4EBDA); // a step darker than cream (read-only boxes, hover)

  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF4A443B);
  static const Color textTertiary = inkMuted;
  static const Color textMuted = inkMuted;
  static const Color textDisabled = Color(0xFFADA597);

  static const Color border = line;
  static const Color borderLight = Color(0xFFF2ECDF);
  static const Color borderMedium = Color(0xFFD6CBB5);
  static const Color divider = line;
  static const Color cardBorder = line;

  // Category tiles rotate through the accents (spec §2).
  static const Color chipYellow = mustardSoft;
  static const Color chipPeach = orangeSoft;
  static const Color chipGreen = tealSoft;
  static const Color chipBlue = skySoft;
  static const Color chipLavender = Color(0xFFEDE7F7);
  static const List<Color> chipPalette = [mustardSoft, orangeSoft, tealSoft, skySoft];

  // Status roles
  static const Color success = teal;
  static const Color successBg = tealSoft;
  static const Color successText = tealText;
  static const Color successBorder = Color(0xFFA8DCCB);

  static const Color warning = mustard;
  static const Color warningBg = mustardSoft;
  static const Color warningText = mustardText;
  static const Color warningBorder = Color(0xFFF2D27C);
  static const Color pending = warning;
  static const Color pendingBg = warningBg;
  static const Color pendingText = warningText;
  static const Color pendingBorder = warningBorder;

  static const Color error = berry;
  static const Color errorBg = berrySoft;
  static const Color errorText = berryText;
  static const Color errorBorder = Color(0xFFF4B9BB);
  static const Color danger = error;
  static const Color dangerBg = errorBg;
  static const Color dangerText = errorText;

  static const Color info = sky;
  static const Color infoBg = skySoft;
  static const Color infoText = skyText;
  static const Color infoBorder = Color(0xFFB8D8F3);

  static const Color checkedOutBg = Color(0xFFEDE7F7);
  static const Color checkedOutText = Color(0xFF55408F);

  // Admin navigation
  static const Color sidebarBg = surfaceWhite;
  static const Color sidebarActive = mustardSoft;
  static const Color sidebarText = ink;
  static const Color sidebarTextInactive = inkMuted;

  static const Color shadowLight = Color(0x141E1B16);
  static const Color shadowMedium = Color(0x221E1B16);

  // ===== Status badges (spec §9.2: teal confirmed, mustard pending, berry cancelled) =====
  static Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'unpaid':
        return pendingBg;
      case 'approved':
      case 'paid':
      case 'available':
        return successBg;
      case 'checked_in':
      case 'partial':
        return infoBg;
      case 'checked_out':
        return checkedOutBg;
      case 'cancelled':
      case 'rejected':
      case 'maintenance':
        return errorBg;
      default:
        return surfaceVariant;
    }
  }

  static Color getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'unpaid':
        return pendingText;
      case 'approved':
      case 'paid':
      case 'available':
        return successText;
      case 'checked_in':
      case 'partial':
        return infoText;
      case 'checked_out':
        return checkedOutText;
      case 'cancelled':
      case 'rejected':
      case 'maintenance':
        return errorText;
      default:
        return textSecondary;
    }
  }
}
