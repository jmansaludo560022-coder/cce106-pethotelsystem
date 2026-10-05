import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shape tokens (Enhancement Spec §4): 12 for fields and small cards, 20 for
/// main cards and sheets, full pill for buttons and chips.
class AppRadius {
  static const double field = 12;
  static const double small = 12;
  static const double card = 20;
  static const double sheet = 20;
  static const double pill = 999;
}

/// Outline widths (Enhancement Spec §4: the 1.5 px outline is the signature).
class AppBorders {
  static const double width = 1.5;
  static const double hairline = 1.0;
}

/// Shadows. "Pop" = the cartoon look from the reference: a solid ink shadow
/// offset (0, 3) with no blur, used on primary CTAs and featured cards only.
class AppShadows {
  static const List<BoxShadow> pop = [BoxShadow(color: AppColors.ink, offset: Offset(0, 3), blurRadius: 0)];
  static const List<BoxShadow> popPressed = [BoxShadow(color: AppColors.ink, offset: Offset(0, 1), blurRadius: 0)];
  static const List<BoxShadow> soft = [BoxShadow(color: AppColors.shadowLight, blurRadius: 10, offset: Offset(0, 3))];
}

/// Motion tokens (Enhancement Spec §7). Keep UI motion short; the elastic
/// curve is reserved for the mascot.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve mascot = Curves.elasticOut;

  /// Spec §7 guardrail: honour the OS "reduce motion" setting.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when the user asked for reduced motion.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
