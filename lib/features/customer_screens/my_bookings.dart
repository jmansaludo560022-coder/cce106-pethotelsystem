import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/logic/booking_views.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/pet_model.dart';
import '../../models/review_model.dart';
import '../../providers/session_provider.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../services/pet_service.dart';
import '../../services/review_service.dart';
import 'booking_summary.dart';
import 'booking_wizard.dart';
import 'dashboard_screen.dart' show ReviewCard;
import 'payment_processing.dart';
import 'qr_pass.dart';
import 'review_dialog.dart';
import '../../core/constants/app_spacing.dart';

/// C-09 My Bookings (BOOK-009 … BOOK-011, REV-001; Enhancement Spec §9.2).
/// Segmented pills: Upcoming · Completed · Cancelled · Reviews, with counts
/// (reviews live here, not in the navbar — SRC-C p.17). Only the signed-in
/// customer's bookings are shown.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

enum BookingsTab { upcoming, completed, cancelled, reviews }

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  String? _cusID;
  BookingsTab _tab = BookingsTab.upcoming;
  late Stream<List<BookingModel>> _bookings;
  late Stream<List<PaymentModel>> _payments;
  late Stream<List<ReviewModel>> _reviews;
  late Stream<List<PetModel>> _pets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<SessionProvider>().cusID;
    if (id != null && id != _cusID) {
      _cusID = id;
      _init();
    }
  }

  void _init() {
    _bookings = BookingService().streamForCustomer(_cusID!);
    _payments = PaymentService().streamForCustomer(_cusID!);
    _reviews = ReviewService().streamForCustomer(_cusID!);
    _pets = PetService().streamForCustomer(_cusID!);
  }

  void _book() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingWizardScreen()));

  @override
  Widget build(BuildContext context) {
    if (_cusID == null) return const Scaffold(body: LoadingState());
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamStateBuilder<List<BookingModel>>(
          stream: _bookings,
          onRetry: () => setState(_init),
          loadingMessage: 'Loading your bookings…',
          errorTitle: 'Unable to load bookings',
          builder: (context, bookings) => StreamBuilder<List<PaymentModel>>(
            stream: _payments,
            builder: (context, paySnap) => StreamBuilder<List<ReviewModel>>(
              stream: _reviews,
              builder: (context, revSnap) => StreamBuilder<List<PetModel>>(
                stream: _pets,
                builder: (context, petSnap) {
                  final payByBooking = BookingPaymentSummary.groupByBooking(paySnap.data ?? const []);
                  final reviews = revSnap.data ?? const <ReviewModel>[];
                  final reviewByBooking = {for (final r in reviews) r.bookingID ?? r.reviewID: r};
                  final photoByPet = {for (final p in petSnap.data ?? const <PetModel>[]) p.petID: p.petPhoto};
                  final upcoming = BookingViews.upcoming(bookings);
                  final completed = BookingViews.completed(bookings);
                  final cancelled = BookingViews.cancelled(bookings);
                  final reviewed = reviews.map((r) => r.bookingID).toSet();
                  final toReview = completed.where((b) => !reviewed.contains(b.bookingID)).length;

                  Widget list(List<BookingModel> items, Widget empty) => items.isEmpty
                      ? empty
                      : MaxWidth(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                            itemBuilder: (_, i) => BookingCard(
                              booking: items[i],
                              summary: BookingPaymentSummary(items[i], payByBooking[items[i].bookingID] ?? const []),
                              review: reviewByBooking[items[i].bookingID],
                              petPhoto: photoByPet[items[i].petID],
                            ),
                          ),
                        );

                  final body = switch (_tab) {
                    BookingsTab.upcoming => list(
                        upcoming,
                        EmptyState(
                          icon: Icons.event_available_outlined,
                          mascot: MascotPose.wave,
                          topAligned: true,
                          title: 'No upcoming stays',
                          message: 'Book a comfy room for your pet to get started.',
                          actionLabel: 'Book a stay',
                          onAction: _book,
                        ),
                      ),
                    BookingsTab.completed => list(
                        completed,
                        const EmptyState(icon: Icons.done_all_rounded, mascot: MascotPose.sleep, topAligned: true, title: 'No completed stays', message: 'Stays appear here after check-out.'),
                      ),
                    BookingsTab.cancelled => list(
                        cancelled,
                        const EmptyState(icon: Icons.event_busy_outlined, mascot: MascotPose.sleep, topAligned: true, title: 'Nothing cancelled', message: 'Cancelled or declined requests appear here.'),
                      ),
                    BookingsTab.reviews => _ReviewsTab(reviews: reviews, completed: completed),
                  };

                  return Column(children: [
                    const PageHeader(title: 'My Bookings', subtitle: 'Your stays, payments and reviews'),
                    SegmentedPills<BookingsTab>(
                      selected: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                      segments: [
                        PillSegment(BookingsTab.upcoming, 'Upcoming', count: upcoming.length),
                        PillSegment(BookingsTab.completed, 'Completed', count: completed.length),
                        PillSegment(BookingsTab.cancelled, 'Cancelled', count: cancelled.length),
                        PillSegment(BookingsTab.reviews, 'Reviews', count: toReview),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.of(context, AppMotion.normal),
                        child: KeyedSubtree(key: ValueKey(_tab), child: body),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Booking card (Enhancement Spec §9.2): pet photo, room, dates with nights,
/// status, total and a chevron; upcoming stays show a countdown.
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final BookingPaymentSummary summary;
  final ReviewModel? review;
  final String? petPhoto;
  const BookingCard({super.key, required this.booking, required this.summary, this.review, this.petPhoto});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerBookingDetailsScreen(bookingID: b.bookingID)));
    final set = bookingActionSet(context, b, summary, review);
    // Two main buttons fit a phone card. Cancel joins them when there is
    // room; otherwise it becomes a link below, so it is never hidden.
    final buttons = set.primary.take(2).toList();
    final cancelInRow = set.cancel != null && buttons.length < 2;
    if (cancelInRow) buttons.insert(0, set.cancel!);
    final upcoming = BookingViews.isUpcoming(b);
    return AppCard(
      onTap: open,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((petPhoto ?? '').isNotEmpty)
            AppImage(url: petPhoto!, width: 52, height: 52, radius: AppRadius.small)
          else
            const IconTile(icon: Icons.pets_rounded, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.roomTypeName.isNotEmpty ? b.roomTypeName : b.roomLabel, style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
              Text('${b.petLabel} · ${b.roomLabel}', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted), overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text('${Fmt.range(b.checkInDate, b.checkOutDate)} · ${Fmt.nights(b.nightsCount)}', style: AppTextStyles.labelMediumRole)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ]),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs + 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusBadge(status: b.status),
          if (!b.isCancelled && !b.isRejected) StatusBadge(status: summary.status, label: summary.status.toUpperCase()),
          if (upcoming) TagChip(BookingViews.countdown(b, DateTime.now()), color: AppColors.mustardSoft, icon: Icons.schedule_rounded),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(child: Text('Ref ${Fmt.ref(b.bookingID)}', style: AppTextStyles.captionSmall)),
          Text(Fmt.peso(b.totalAmount), style: AppTextStyles.priceSmall),
        ]),
        if (b.isRejected && b.rejectionReason.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Reason: ${b.rejectionReason}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorText)),
        ],
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: buttons[i]),
            ],
          ]),
        ],
        if (set.cancel != null && !cancelInRow)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => cancelBookingFlow(context, b),
              icon: const Icon(Icons.event_busy_outlined, size: 18, color: AppColors.errorText),
              label: Text('Cancel booking', style: AppTextStyles.labelLargeRole.copyWith(color: AppColors.errorText)),
            ),
          ),
      ]),
    );
  }
}

/// The actions for a booking, most important first. Cancel is kept apart so
/// a card can show it as a link when its two button slots are taken.
class BookingActionSet {
  final List<Widget> primary;
  final Widget? cancel;
  const BookingActionSet(this.primary, this.cancel);
}

/// Shared by the booking card and the details screen, so both always offer
/// the same actions. A confirmed stay shows its QR pass first (it was hidden
/// behind Cancel and Pay Now before — found in live testing, 2026-10-03).
BookingActionSet bookingActionSet(BuildContext context, BookingModel b, BookingPaymentSummary summary, ReviewModel? review) {
  final out = <Widget>[];
  if (b.isQrPassUnlocked) {
    out.add(InkButton(
      label: 'QR Pass',
      icon: Icons.qr_code_2_rounded,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QrPassScreen(bookingID: b.bookingID))),
    ));
  }
  if ((b.isPending || b.isApproved) && summary.balance > 0) {
    out.add(SecondaryButton(
      label: 'Pay Now',
      icon: Icons.account_balance_wallet_outlined,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PayNowScreen(booking: b, balance: summary.balance))),
    ));
  }
  if (b.isCheckedOut) {
    out.add(PrimaryButton(
      label: review == null ? 'Write Review' : 'Edit Review',
      icon: Icons.rate_review_outlined,
      onPressed: () => showReviewSheet(context, booking: b, existing: review),
    ));
  }
  final cancel = canCustomerCancel(b.status, b.checkInDate)
      ? DestructiveButton(label: 'Cancel', onPressed: () => cancelBookingFlow(context, b))
      : null;
  return BookingActionSet(out, cancel);
}

/// Every action for a booking (details screen), cancel last.
List<Widget> bookingActions(BuildContext context, BookingModel b, BookingPaymentSummary summary, ReviewModel? review) {
  final set = bookingActionSet(context, b, summary, review);
  return [...set.primary, ?set.cancel];
}

Future<void> cancelBookingFlow(BuildContext context, BookingModel b) async {
  final ok = await confirmDialog(
    context,
    title: 'Cancel this booking?',
    message: 'Room ${b.roomNum} for ${b.petLabel}, ${Fmt.range(b.checkInDate, b.checkOutDate)}. This releases the room slot and cannot be undone.',
    confirmLabel: 'Yes, cancel',
    cancelLabel: 'Keep booking',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  try {
    await BookingService().customerCancel(b);
    if (context.mounted) showSuccess(context, 'Booking cancelled.');
  } catch (e) {
    if (context.mounted) showError(context, friendlyError(e));
  }
}

class _ReviewsTab extends StatelessWidget {
  final List<ReviewModel> reviews;
  final List<BookingModel> completed;
  const _ReviewsTab({required this.reviews, required this.completed});

  @override
  Widget build(BuildContext context) {
    final reviewed = reviews.map((r) => r.bookingID).toSet();
    final toReview = completed.where((b) => !reviewed.contains(b.bookingID)).toList();
    if (reviews.isEmpty && toReview.isEmpty) {
      return const EmptyState(icon: Icons.rate_review_outlined, mascot: MascotPose.sleep, topAligned: true, title: 'No reviews yet', message: 'After a completed stay, you can rate it here.');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
      if (toReview.isNotEmpty) ...[
        const SectionHeader('Waiting for your review'),
        for (final b in toReview) ...[
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b.roomTypeName} · ${b.roomLabel}', style: AppTextStyles.labelLarge),
                  Text('${b.petLabel} · ${Fmt.range(b.checkInDate, b.checkOutDate)}', style: AppTextStyles.caption),
                ]),
              ),
              PrimaryButton(label: 'Review', fullWidth: false, onPressed: () => showReviewSheet(context, booking: b)),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
      if (reviews.isNotEmpty) ...[
        const SectionHeader('Your reviews'),
        for (final r in reviews) ...[
          ReviewCard(
            review: r,
            trailing: TextButton(
              onPressed: () {
                final b = completed.where((x) => x.bookingID == r.bookingID).firstOrNull;
                if (b != null) showReviewSheet(context, booking: b, existing: r);
              },
              child: const Text('Edit'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ]);
  }
}
