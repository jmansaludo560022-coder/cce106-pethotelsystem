import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import 'booking_summary.dart';
import 'customer_shell.dart';
import '../../core/constants/app_spacing.dart';

/// C-08 Booking submitted (Figma booking step 5). Reads the booking back from
/// Firestore so what is shown is what was actually saved.
///
/// (This file previously contained a misplaced CancelBookingDialog; cancelling
/// now uses the shared confirmation dialog in My Bookings.)
class BookingSubmittedScreen extends StatefulWidget {
  final String bookingID;
  final bool walkIn;
  const BookingSubmittedScreen({super.key, required this.bookingID, this.walkIn = false});

  @override
  State<BookingSubmittedScreen> createState() => _BookingSubmittedScreenState();
}

class _BookingSubmittedScreenState extends State<BookingSubmittedScreen> {
  late final Stream<BookingModel?> _booking = BookingService().streamBooking(widget.bookingID);

  void _goTo(CustomerTab? tab) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (tab != null) CustomerShell.tabRequest.value = tab;
  }

  /// "View booking": back to the shell on the Bookings tab, then open this booking.
  void _viewBooking() {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    CustomerShell.tabRequest.value = CustomerTab.bookings;
    nav.push(MaterialPageRoute(builder: (_) => CustomerBookingDetailsScreen(bookingID: widget.bookingID)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.walkIn ? 'Walk-in Confirmed' : 'Booking Submitted'),
        automaticallyImplyLeading: false,
      ),
      body: StreamStateBuilder<BookingModel?>(
        stream: _booking,
        loadingMessage: 'Loading your booking…',
        builder: (context, b) {
          if (b == null) {
            return const EmptyState(icon: Icons.search_off_rounded, title: 'Booking not found', message: 'It may have been removed.');
          }
          return MaxWidth(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxl), children: [
              // Spec §7 success moment: the mascot cheers (pop-in; fade only with reduced motion).
              const Center(child: _CheerPop()),
              const SizedBox(height: AppSpacing.lg),
              Text(widget.walkIn ? 'Walk-in booking confirmed!' : 'Request received!', style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                widget.walkIn
                    ? 'The stay is confirmed and appears in Bookings and Payments.'
                    : 'The hotel will review your booking. Once approved, your digital QR pass unlocks in My Bookings.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(color: AppColors.mustardSoft, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: AppColors.ink, width: AppBorders.width)),
                  child: Text('Ref ${Fmt.ref(b.bookingID)}', style: AppTextStyles.labelLargeRole),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                child: Column(children: [
                  InfoRow('Pet', b.petLabel),
                  InfoRow('Room', '${b.roomLabel} · ${b.roomTypeName}'),
                  InfoRow('Check-in', Fmt.date(b.checkInDate)),
                  InfoRow('Check-out', Fmt.date(b.checkOutDate)),
                  InfoRow('Status', b.displayStatus),
                  const DashedDivider(),
                  InfoRow('Total', Fmt.peso(b.totalAmount), emphasize: true),
                ]),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (widget.walkIn)
                PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop())
              else ...[
                PrimaryButton(label: 'View booking', icon: Icons.receipt_long_rounded, onPressed: _viewBooking),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(label: 'Back to home', onPressed: () => _goTo(CustomerTab.home)),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _CheerPop extends StatelessWidget {
  const _CheerPop();

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: reduced ? Curves.easeOut : AppMotion.mascot,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: reduced ? child : Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: const Mascot(pose: MascotPose.cheer, size: 150, semanticLabel: 'Mascot cheering'),
    );
  }
}
