import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography (Enhancement Spec §3).
///
/// * **Fredoka** (rounded) for headings and brand moments only — never in
///   paragraphs, inputs or buttons.
/// * **Plus Jakarta Sans** for everything users read or type.
/// * Material 3 sizes; body text 14–16 sp; only weights 400, 500/600 and 700
///   (700 for prices and key numbers). Text typed into a field is always
///   bodyLarge 400 — never bold.
///
/// The spec roles are mapped into [ThemeData.textTheme] in AppTheme. The older
/// names below (headingSmall, caption, …) are kept as aliases of the spec roles.
/// Compact scale (2026-10-03): one step smaller than spec §3 so phone screens
/// are not dominated by large text; the smallest sizes stay at 11–12 for readability.
///
/// so existing screens pick up the new type scale without being rewritten.
class AppTextStyles {
  static const String display = 'Fredoka';
  static const String text = 'PlusJakartaSans';

  /// The bundled fonts lack the peso sign (₱); this tiny font supplies it.
  static const List<String> pesoFallback = ['PlusJakartaSansPeso'];

  // ===== Spec §3 roles =====
  static const TextStyle displaySmall = TextStyle(fontFamily: display, fontFamilyFallback: pesoFallback, fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const TextStyle headlineSmall = TextStyle(fontFamily: display, fontFamilyFallback: pesoFallback, fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const TextStyle titleLarge = TextStyle(fontFamily: display, fontFamilyFallback: pesoFallback, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const TextStyle titleMedium = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const TextStyle bodyLargeRole = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: AppColors.ink);
  static const TextStyle bodyMediumRole = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const TextStyle bodySmallRole = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400, color: AppColors.inkMuted);
  static const TextStyle labelLargeRole = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const TextStyle labelMediumRole = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: AppColors.ink);
  static const TextStyle labelSmallRole = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500, color: AppColors.inkMuted);

  // ===== Aliases used across existing screens =====
  static const TextStyle displayLarge = displaySmall;
  static const TextStyle displayMedium = headlineSmall;
  static const TextStyle headingLarge = headlineSmall;
  static const TextStyle headingMedium = titleLarge;
  static const TextStyle headingSmall = titleMedium;

  static const TextStyle bodyLarge = bodyLargeRole;
  static const TextStyle bodyMedium = bodyMediumRole;
  static const TextStyle bodySmall = bodySmallRole;

  static const TextStyle labelLarge = labelLargeRole;
  /// Values in summaries (InfoRow etc.): body size, medium weight.
  static const TextStyle labelMedium = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: AppColors.ink);
  static const TextStyle labelSmall = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);

  static const TextStyle caption = bodySmallRole;
  static const TextStyle captionSmall = labelSmallRole;

  // Buttons use labelLarge (spec §3). Colors come from the button theme.
  static const TextStyle buttonLarge = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static const TextStyle buttonMedium = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600);
  static const TextStyle buttonSmall = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600);

  // Prices and key numbers: 700 (spec §3).
  static const TextStyle priceDisplay = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const TextStyle priceMedium = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const TextStyle priceSmall = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w700, color: AppColors.ink);

  static const TextStyle statusBadge = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, letterSpacing: 0.3);
  static const TextStyle chipLabel = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500);

  // Fields (spec §8): label labelMedium 500 inkMuted; value bodyLarge 400 ink.
  static const TextStyle inputLabel = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: AppColors.inkMuted);
  /// Text the user types or selects in a field: ALWAYS regular weight (spec §3, §8).
  static const TextStyle inputText = bodyLargeRole;
  static const TextStyle inputHint = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: AppColors.textDisabled);
  static const TextStyle inputError = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400, color: AppColors.berryText);

  /// Banner / notice text (bodyMedium) on the soft info / warning tints, and on ink.
  static const TextStyle infoBanner = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: AppColors.infoText);
  static const TextStyle warningBanner = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: AppColors.warningText);
  static const TextStyle onInkBody = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: AppColors.onInk);

  /// Navigation labels (spec §6): active 600, inactive 500.
  static const TextStyle navLabel = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: AppColors.inkMuted);
  static const TextStyle navLabelActive = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: AppColors.ink);
  /// Admin menu rows (labelLarge size): active 600, inactive 500.
  static const TextStyle menuItem = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static const TextStyle menuItemActive = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: AppColors.ink);

  static const TextStyle link = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: AppColors.skyText);
  static const TextStyle linkBold = TextStyle(fontFamily: text, fontFamilyFallback: pesoFallback, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, color: AppColors.ink, decoration: TextDecoration.underline);
}
