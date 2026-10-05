import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Numbered step progress (Figma booking steps 1–4). Completed steps show a check.
class StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int current; // 0-based
  const StepIndicator({super.key, required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final done = i < current;
      final active = i == current;
      items.add(Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.ink : (active ? AppColors.primary : AppColors.surface),
            border: Border.all(color: done || active ? Colors.transparent : AppColors.borderMedium),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.onInk)
              : Text('${i + 1}', style: AppTextStyles.labelSmall.copyWith(color: active ? AppColors.onPrimary : AppColors.textMuted)),
        ),
        const SizedBox(height: 4),
        Text(steps[i], style: AppTextStyles.captionSmall.copyWith(color: active ? AppColors.textPrimary : AppColors.textMuted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ]));
      if (i < steps.length - 1) {
        items.add(Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
            color: i < current ? AppColors.ink : AppColors.border,
          ),
        ));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: items);
  }
}
