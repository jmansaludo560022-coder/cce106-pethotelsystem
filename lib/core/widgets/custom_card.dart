import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_tokens.dart';
import 'pressable.dart';

/// The signature outlined card (Enhancement Spec §2/§4): white surface,
/// 1.5 px border, radius 20. [pop] = ink outline + solid pop shadow for
/// featured cards. Tappable cards get the 0.97 press feedback (spec §7).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool pop;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
    this.pop = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    Widget card(bool pressed) => Container(
          margin: margin,
          decoration: BoxDecoration(
            color: color ?? AppColors.surface,
            borderRadius: radius,
            border: Border.all(color: borderColor ?? (pop ? AppColors.ink : AppColors.line), width: AppBorders.width),
            boxShadow: pop ? (pressed ? AppShadows.popPressed : AppShadows.pop) : AppShadows.soft,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
          ),
        );
    if (onTap == null) return card(false);
    return Pressable(builder: (context, pressed) => card(pressed));
  }
}

/// Soft tinted panel (summaries, notes).
class TintedCard extends StatelessWidget {
  final Widget child;
  final Color tintColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  const TintedCard({super.key, required this.child, required this.tintColor, this.borderColor, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: tintColor,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: child,
      );
}
