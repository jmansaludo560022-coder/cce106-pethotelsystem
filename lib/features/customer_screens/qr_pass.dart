import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../core/constants/app_spacing.dart';

/// C-12 Digital pass (QR-001; Figma "View Digital Pass").
/// Listens to the booking live, so after the admin scans a code the screen
/// updates immediately.
class QrPassScreen extends StatefulWidget {
  final String bookingID;
  const QrPassScreen({super.key, required this.bookingID});

  @override
  State<QrPassScreen> createState() => _QrPassScreenState();
}

class _QrPassScreenState extends State<QrPassScreen> {
  late final Stream<BookingModel?> _booking = BookingService().streamBooking(widget.bookingID);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Pass')),
      body: StreamStateBuilder<BookingModel?>(
        stream: _booking,
        loadingMessage: 'Loading pass…',
        builder: (context, b) => b == null
            ? const EmptyState(icon: Icons.search_off_rounded, title: 'Booking not found', message: 'It may have been removed.')
            : MaxWidth(maxWidth: 560, child: QrPassView(booking: b)),
      ),
    );
  }
}

/// Pass content; separated so it can be widget-tested without Firebase.
class QrPassView extends StatelessWidget {
  final BookingModel booking;
  const QrPassView({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
      AppCard(
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('${b.petLabel} · ${b.roomLabel}', style: AppTextStyles.headingSmall)),
            StatusBadge(status: b.status),
          ]),
          const SizedBox(height: 6),
          InfoRow('Booking ref', Fmt.ref(b.bookingID)),
          InfoRow('Stay', Fmt.range(b.checkInDate, b.checkOutDate)),
          InfoRow('Arrival', b.checkInTimeSlot.split(' (').first),
        ]),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (!b.isQrPassUnlocked && !b.isCheckedOut)
        TintedCard(
          tintColor: AppColors.warningBg,
          child: Column(children: [
            const Icon(Icons.lock_clock_rounded, size: 40, color: AppColors.warningText),
            const SizedBox(height: AppSpacing.sm),
            const Text('Pass locked', style: AppTextStyles.headingSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              b.isPending
                  ? 'Your QR pass unlocks once the hotel approves this booking.'
                  : 'This booking is ${b.displayStatus.toLowerCase()}, so no pass is available.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ]),
        )
      else ...[
        const Text('Check-in & check-out QR codes', style: AppTextStyles.headingSmall),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final checkIn = _QrTile(
            title: 'Check-in QR',
            payload: QrPayload(b.bookingID, QrAction.checkIn).encode(),
            active: b.isApproved,
            note: b.isApproved ? 'Show at arrival' : 'Used',
          );
          final checkOut = _QrTile(
            title: 'Check-out QR',
            payload: QrPayload(b.bookingID, QrAction.checkOut).encode(),
            active: b.isCheckedIn,
            note: b.isCheckedIn ? 'Show at pick-up' : (b.isCheckedOut ? 'Used' : 'Available after check-in'),
          );
          if (c.maxWidth < 300) return Column(children: [checkIn, const SizedBox(height: AppSpacing.md), checkOut]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: checkIn),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: checkOut),
          ]);
        }),
        const SizedBox(height: AppSpacing.lg),
        const TintedCard(
          tintColor: AppColors.surfaceVariant,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How to use your pass', style: AppTextStyles.labelLarge),
            SizedBox(height: 6),
            Text('• Arrive at the Matina, Davao City front desk during your arrival slot.', style: AppTextStyles.bodySmall),
            Text('• Show the Check-in QR; staff scan it to check your pet in.', style: AppTextStyles.bodySmall),
            Text('• When picking up, show the Check-out QR.', style: AppTextStyles.bodySmall),
            Text('• Check-in is accepted from the check-in date until the check-out date.', style: AppTextStyles.bodySmall),
          ]),
        ),
      ],
    ]);
  }
}

class _QrTile extends StatelessWidget {
  final String title;
  final String payload;
  final bool active;
  final String note;
  const _QrTile({required this.title, required this.payload, required this.active, required this.note});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: active ? AppColors.ink : null,
      child: Column(children: [
        Text(title, style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Opacity(
          opacity: active ? 1 : 0.18,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(builder: (_, c) => QrImageView(data: payload, size: c.maxWidth.clamp(80, 170).toDouble(), semanticsLabel: '$title code')),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StatusBadge(status: active ? 'approved' : 'unknown', label: note.toUpperCase()),
      ]),
    );
  }
}
