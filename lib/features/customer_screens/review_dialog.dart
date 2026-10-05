import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/review_model.dart';
import '../../providers/session_provider.dart';
import '../../services/review_service.dart';
import '../../core/constants/app_spacing.dart';

/// C-11 Write / edit review (REV-001, REV-002). The review is linked to the
/// signed-in customer and the booking — the customer no longer types a name
/// and no random customer ID is generated (ISS-23).
Future<void> showReviewSheet(BuildContext context, {required BookingModel booking, ReviewModel? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(booking: booking, existing: existing),
  );
}

class _ReviewSheet extends StatefulWidget {
  final BookingModel booking;
  final ReviewModel? existing;
  const _ReviewSheet({required this.booking, this.existing});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late double _rating = widget.existing?.rating ?? 0;
  late final _text = TextEditingController(text: widget.existing?.comment ?? '');
  bool _saving = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating < 1) {
      showError(context, 'Please choose a star rating.');
      return;
    }
    if (_text.text.trim().isEmpty) {
      showError(context, 'Please write a short review.');
      return;
    }
    setState(() => _saving = true);
    try {
      final name = context.read<SessionProvider>().customer?.fullName ?? widget.booking.customerName;
      await ReviewService().submit(booking: widget.booking, customerName: name, rating: _rating, comment: _text.text, existing: widget.existing);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, widget.existing == null ? 'Thanks for your review!' : 'Review updated.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing == null ? 'Rate your stay' : 'Edit your review', style: AppTextStyles.headingMedium),
        Text('${b.roomTypeName} · ${b.roomLabel} · ${b.petLabel} · ${Fmt.range(b.checkInDate, b.checkOutDate)}', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final filled = _rating >= i + 1;
              return IconButton(
                tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
                iconSize: 38,
                onPressed: () => setState(() => _rating = i + 1.0),
                icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.warning),
              );
            }),
          ),
        ),
        Center(child: Text(_labels[_rating.round()], style: AppTextStyles.labelMedium)),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _text,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Your review', hintText: 'How was your pet\'s stay?', alignLabelWithHint: true),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(label: widget.existing == null ? 'Submit review' : 'Save changes', isLoading: _saving, onPressed: _save),
      ]),
    );
  }
}
