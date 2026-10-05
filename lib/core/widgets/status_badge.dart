import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// Pill status badge. Colors come from [AppColors.getStatusBgColor].
class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  const StatusBadge({super.key, required this.status, this.label});

  static String labelFor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'CONFIRMED';
      case 'checked_in':
        return 'CHECKED IN';
      case 'checked_out':
        return 'COMPLETED';
      case 'rejected':
        return 'REJECTED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.getStatusBgColor(status), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label ?? labelFor(status),
        style: AppTextStyles.statusBadge.copyWith(color: AppColors.getStatusTextColor(status)),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Small colored category chip (e.g. room type name).
class TagChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const TagChip(this.text, {super.key, this.color = AppColors.chipBlue, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: AppColors.textSecondary), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
        ]),
      );
}
