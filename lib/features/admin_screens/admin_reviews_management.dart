import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../customer_screens/dashboard_screen.dart' show ReviewCard, StarRow;

/// A-09 Reviews management (REV-004; SRC-F p.16–17).
/// The admin can ONLY view and delete reviews. Reply, approve/hide moderation
/// and flag features were removed as the specification requires.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  late Stream<List<ReviewModel>> _reviews = ReviewService().streamAll();
  String _rating = 'All';

  Future<void> _delete(ReviewModel r) async {
    final ok = await confirmDialog(context, title: 'Delete this review?', message: 'Review by ${r.custName}. This cannot be undone.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    try {
      await ReviewService().delete(r.reviewID);
      if (mounted) showSuccess(context, 'Review deleted.');
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
  }

  void _view(ReviewModel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Review details', style: AppTextStyles.headingMedium),
            const SizedBox(height: 10),
            InfoRow('Customer', r.custName),
            if ((r.petName ?? '').isNotEmpty) InfoRow('Pet', r.petName!),
            if ((r.roomTypeName ?? '').isNotEmpty) InfoRow('Room type', r.roomTypeName!),
            if ((r.bookingID ?? '').isNotEmpty) InfoRow('Booking ref', Fmt.ref(r.bookingID!)),
            InfoRow('Date', Fmt.dateTime(r.createdAt)),
            const SizedBox(height: AppSpacing.sm),
            StarRow(rating: r.rating),
            const SizedBox(height: AppSpacing.sm),
            Text(r.comment, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 18),
            DestructiveButton(
              label: 'Delete review',
              icon: Icons.delete_outline_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                _delete(r);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamStateBuilder<List<ReviewModel>>(
      stream: _reviews,
      onRetry: () => setState(() => _reviews = ReviewService().streamAll()),
      loadingMessage: 'Loading reviews…',
      errorTitle: 'Unable to load reviews',
      builder: (context, all) {
        final avg = all.isEmpty ? 0.0 : all.fold<double>(0, (s, r) => s + r.rating) / all.length;
        final list = all.where((r) {
          return switch (_rating) {
            '5★' => r.rating >= 5,
            '4★' => r.rating >= 4 && r.rating < 5,
            '3★' => r.rating >= 3 && r.rating < 4,
            '1–2★' => r.rating < 3,
            _ => true,
          };
        }).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl), children: [
          Row(children: [
            Expanded(child: StatTile(label: 'Total reviews', value: '${all.length}', icon: Icons.reviews_outlined, tint: AppColors.chipBlue)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: StatTile(label: 'Average rating', value: all.isEmpty ? '—' : avg.toStringAsFixed(1), icon: Icons.star_rounded, tint: AppColors.chipYellow)),
          ]),
          const SizedBox(height: AppSpacing.md),
          FilterChipsRow(options: const ['All', '5★', '4★', '3★', '1–2★'], selected: _rating, onSelected: (v) => setState(() => _rating = v)),
          const SizedBox(height: AppSpacing.md),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews', message: 'Customer reviews appear here after completed stays.')),
          for (final r in list) ...[
            GestureDetector(
              onTap: () => _view(r),
              child: ReviewCard(
                review: r,
                trailing: IconButton(tooltip: 'Delete review', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error), onPressed: () => _delete(r)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }
}
