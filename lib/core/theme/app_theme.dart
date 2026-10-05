import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_tokens.dart';
import 'field_border.dart';

/// Application theme (master spec §4). All screens take their look from here;
/// screens must NOT override AppBar colors individually.
///
/// ISS-03 fix: the AppBar background is the cream page color and the title and
/// icons are dark ink, so titles and back arrows are always readable (before,
/// screens painted the AppBar white while the theme painted text white).
class AppTheme {
  static ThemeData lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.ink,
      onSecondary: AppColors.onInk,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.onInk,
      outline: AppColors.border,
    );

    const pill = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 13);

    // Instagram-style field (spec §8): label inside the box, never in the line.
    FieldBorder field(Color c, {double w = AppBorders.hairline, bool glow = false}) =>
        FieldBorder(borderSide: BorderSide(color: c, width: w), radius: AppRadius.field, glow: glow);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.text,
      fontFamilyFallback: AppTextStyles.pesoFallback, // Plus Jakarta Sans everywhere by default (spec §3)
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        // Flat until the page scrolls, then a hairline in the line colour (spec §6).
        scrolledUnderElevation: 1,
        shadowColor: AppColors.line,
        centerTitle: true,
        titleTextStyle: AppTextStyles.titleMedium,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: AppSpacing.iconSizeMedium),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.line, width: AppBorders.width),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.borderLight,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          shape: pill,
          side: const BorderSide(color: AppColors.ink, width: AppBorders.width),
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          shape: pill,
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.ink, width: AppBorders.width),
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          shape: pill,
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: pill,
          textStyle: AppTextStyles.buttonMedium,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        shape: StadiumBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // White box on cream screens; cream when disabled (spec §8).
        fillColor: WidgetStateColor.resolveWith((st) => st.contains(WidgetState.disabled) ? AppColors.cream : AppColors.surface),
        // Compact, familiar field height (~48 dp) — owner request 2026-10-03.
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
        hoverColor: AppColors.surfaceVariant, // web/desktop hover: cream tint, not Material grey
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        // Empty: label inside the box (bodyLarge 400 inkMuted); focused/filled:
        // it shrinks to the top-left inside the box (labelMedium 500), ink on focus.
        labelStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((st) => AppTextStyles.inputLabel.copyWith(
              color: st.contains(WidgetState.error)
                  ? AppColors.berryText
                  : (st.contains(WidgetState.focused) ? AppColors.ink : AppColors.inkMuted),
            )),
        hintStyle: AppTextStyles.inputHint,
        helperStyle: AppTextStyles.bodySmall,
        errorStyle: AppTextStyles.inputError,
        errorMaxLines: 2,
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
        border: field(AppColors.line),
        enabledBorder: field(AppColors.line),
        focusedBorder: field(AppColors.ink, w: AppBorders.width, glow: true),
        errorBorder: field(AppColors.berry),
        focusedErrorBorder: field(AppColors.berry, w: AppBorders.width),
        disabledBorder: field(AppColors.borderLight),
      ),

      // Detail and flow screens: circular outlined 40 dp back button (spec §6).
      actionIconTheme: ActionIconThemeData(backButtonIconBuilder: (_) => const CircleBackIcon()),

      // Brand-coloured date range picker (spec §9.3).
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        // Ink header with ivory text: strong contrast even for the faded
        // "Start Date – End Date" placeholder (was mustard on mustard).
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: AppColors.onInk,
        headerHeadlineStyle: AppTextStyles.headlineSmall.copyWith(color: AppColors.onInk),
        rangePickerBackgroundColor: AppColors.cream,
        rangePickerHeaderBackgroundColor: AppColors.ink,
        rangePickerHeaderForegroundColor: AppColors.onInk,
        rangeSelectionBackgroundColor: AppColors.mustardSoft,
        todayBorder: const BorderSide(color: AppColors.ink, width: AppBorders.width),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.ink),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? AppColors.textDisabled : AppColors.ink),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.mustard : Colors.transparent),
        dayStyle: AppTextStyles.bodyMediumRole,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.mustardSoft,
        disabledColor: AppColors.borderLight,
        labelStyle: AppTextStyles.chipLabel.copyWith(color: AppColors.textPrimary),
        secondaryLabelStyle: AppTextStyles.chipLabel.copyWith(color: AppColors.ink),
        checkmarkColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line, width: AppBorders.width),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.bodyMedium,
        dividerColor: AppColors.border,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => AppTextStyles.captionSmall.copyWith(
              color: s.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.textMuted,
            )),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.modalRadius)),
        titleTextStyle: AppTextStyles.headingSmall,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.bottomSheetRadius)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.onInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : null),
        checkColor: const WidgetStatePropertyAll(AppColors.onInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.textMuted),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
      // Spec §3 type scale; screens use Theme.of(context).textTheme.
      textTheme: const TextTheme(
        displaySmall: AppTextStyles.displaySmall,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.labelLargeRole,
        bodyLarge: AppTextStyles.bodyLargeRole,
        bodyMedium: AppTextStyles.bodyMediumRole,
        bodySmall: AppTextStyles.bodySmallRole,
        labelLarge: AppTextStyles.labelLargeRole,
        labelMedium: AppTextStyles.labelMediumRole,
        labelSmall: AppTextStyles.labelSmallRole,
      ),
    );
  }
}

/// The back icon used by every app bar: arrow in a 40 dp outlined circle.
class CircleBackIcon extends StatelessWidget {
  const CircleBackIcon({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: AppBorders.width),
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
      );
}
