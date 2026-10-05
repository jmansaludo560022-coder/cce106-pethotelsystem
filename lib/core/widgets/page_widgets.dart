import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_tokens.dart';
import '../utils/formatters.dart';
import 'pressable.dart';

/// Large left-aligned header for root tabs (Enhancement Spec §6): replaces
/// the plain centered app bar on Home, Pets, Bookings and Account.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
          Expanded(
            child: Semantics(
              header: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppTextStyles.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(subtitle!, style: AppTextStyles.bodyMediumRole.copyWith(color: AppColors.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
        ]),
      );
}

/// One option of a [SegmentedPills] control.
class PillSegment<T> {
  final T value;
  final String label;
  final int? count;
  const PillSegment(this.value, this.label, {this.count});
}

/// Segmented pill control with count badges (Enhancement Spec §9.2). Scrolls
/// sideways when the labels do not fit (small phones, large text).
class SegmentedPills<T> extends StatelessWidget {
  final List<PillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedPills({super.key, required this.segments, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.fast);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink, width: AppBorders.width),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final s in segments)
            Semantics(
              button: true,
              selected: s.value == selected,
              label: s.count == null ? s.label : '${s.label}, ${s.count}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onChanged(s.value),
                child: AnimatedContainer(
                  duration: duration,
                  curve: AppMotion.enter,
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: s.value == selected ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      s.label,
                      style: AppTextStyles.labelLargeRole.copyWith(color: s.value == selected ? AppColors.onInk : AppColors.inkMuted),
                    ),
                    if (s.count != null && s.count! > 0) ...[
                      const SizedBox(width: AppSpacing.xs + 2),
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2, vertical: 1),
                        decoration: BoxDecoration(
                          color: s.value == selected ? AppColors.mustard : AppColors.mustardSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('${s.count}', textAlign: TextAlign.center, style: AppTextStyles.labelSmallRole.copyWith(color: AppColors.ink)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Booking-flow progress header (Enhancement Spec §9.3): step title,
/// "Step 1 of 4" and a segmented bar that fills in mustard.
class BookingProgressHeader extends StatelessWidget {
  final String title;
  final int step; // 0-based
  final int total;

  const BookingProgressHeader({super.key, required this.title, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.normal);
    return Semantics(
      label: 'Step ${step + 1} of $total: $title',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Step ${step + 1} of $total', style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.inkMuted)),
        const SizedBox(height: AppSpacing.xs / 2),
        Text(title, style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.ink, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      key: ValueKey('progress-$i'),
                      duration: duration,
                      curve: AppMotion.enter,
                      widthFactor: i <= step ? 1 : 0,
                      child: const ColoredBox(color: AppColors.mustard, child: SizedBox.expand()),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// A peso amount that rolls to its new value (Enhancement Spec §9.3).
/// With reduced motion it changes instantly.
class AnimatedPeso extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String emptyText;

  const AnimatedPeso({super.key, required this.value, required this.style, this.emptyText = '—'});

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return Text(emptyText, style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: AppMotion.of(context, AppMotion.slow),
      curve: AppMotion.enter,
      builder: (_, v, _) => Text(Fmt.peso(v), style: style, semanticsLabel: Fmt.peso(value)),
    );
  }
}

/// Dashed rule for receipt-style summaries.
class DashedDivider extends StatelessWidget {
  final double height;
  const DashedDivider({super.key, this.height = AppSpacing.xl});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(child: CustomPaint(size: const Size(double.infinity, 1.5), painter: _DashPainter())),
      );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.inkMuted
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const dash = 6.0, gap = 5.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small outlined icon tile used for trust badges and service icons.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile({super.key, required this.icon, this.color = AppColors.mustardSoft, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.ink, width: AppBorders.width),
        ),
        child: Icon(icon, size: size * 0.5, color: AppColors.ink),
      );
}

/// Selectable card for the booking flow (Enhancement Spec §7): the selected
/// card gets an ink border on mustard-soft, a check badge pops in, and the
/// card lifts slightly. Disabled cards are dimmed and explain why via [child].
class SelectableCard extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  const SelectableCard({super.key, required this.selected, required this.onTap, required this.child, this.enabled = true, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final fast = AppMotion.of(context, AppMotion.fast);
    final reduced = AppMotion.reduced(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Pressable(
          enabled: enabled,
          builder: (context, pressed) => AnimatedContainer(
            duration: fast,
            transform: Matrix4.translationValues(0, selected && !reduced ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: selected ? AppColors.mustardSoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: AppBorders.width),
              boxShadow: selected ? AppShadows.pop : const [],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Expanded(child: child),
                    AnimatedScale(
                      duration: fast,
                      curve: Curves.easeOutBack,
                      scale: selected ? 1 : 0,
                      child: const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.sm),
                        child: Icon(Icons.check_circle_rounded, color: AppColors.ink),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
