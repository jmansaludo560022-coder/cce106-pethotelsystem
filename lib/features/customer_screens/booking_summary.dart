import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ph_phone.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/review_model.dart';
import '../../providers/session_provider.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../services/review_service.dart';
import 'my_bookings.dart' show bookingActions;

/// C-10 Booking details ("View" action, BOOK-010 / SRC-C p.17): pet, room
/// number, dates, add-ons, price breakdown, payment status and history, and
/// the same actions as the booking card.
class CustomerBookingDetailsScreen extends StatefulWidget {
  final String bookingID;
  const CustomerBookingDetailsScreen({super.key, required this.bookingID});

  @override
  State<CustomerBookingDetailsScreen> createState() => _CustomerBookingDetailsScreenState();
}

class _CustomerBookingDetailsScreenState extends State<CustomerBookingDetailsScreen> {
  late final Stream<BookingModel?> _booking = BookingService().streamBooking(widget.bookingID);
  late Stream<List<PaymentModel>> _payments;
  late Stream<List<ReviewModel>> _reviews;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cusID = context.read<SessionProvider>().cusID ?? '_none_';
    _payments = PaymentService().streamForCustomer(cusID);
    _reviews = ReviewService().streamForCustomer(cusID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: StreamStateBuilder<BookingModel?>(
        stream: _booking,
        loadingMessage: 'Loading booking…',
        builder: (context, b) {
          if (b == null) return const EmptyState(icon: Icons.search_off_rounded, title: 'Booking not found', message: 'It may have been removed.');
          return StreamBuilder<List<PaymentModel>>(
            stream: _payments,
            builder: (context, ps) => StreamBuilder<List<ReviewModel>>(
              stream: _reviews,
              builder: (context, rs) {
                final payments = (ps.data ?? const <PaymentModel>[]).where((p) => p.bookingID == b.bookingID).toList();
                final review = (rs.data ?? const <ReviewModel>[]).where((r) => r.bookingID == b.bookingID).firstOrNull;
                final summary = BookingPaymentSummary(b, payments);
                final actions = bookingActions(context, b, summary, review);
                return BookingDetailsBody(booking: b, summary: summary, footer: actions);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Details layout shared by customer and admin booking screens.
class BookingDetailsBody extends StatelessWidget {
  final BookingModel booking;
  final BookingPaymentSummary summary;
  final List<Widget> footer;
  final bool showCustomer;
  const BookingDetailsBody({super.key, required this.booking, required this.summary, this.footer = const [], this.showCustomer = false});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return MaxWidth(
      child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Ref ${Fmt.ref(b.bookingID)}', style: AppTextStyles.headingSmall)),
              StatusBadge(status: b.status),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text('Requested ${Fmt.dateTime(b.createdAt)}${b.isWalkIn ? ' · Walk-in' : ''}', style: AppTextStyles.caption),
            if (b.isRejected && b.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              TintedCard(tintColor: AppColors.errorBg, child: Text('Reason: ${b.rejectionReason}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorText))),
            ],
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        if (showCustomer) ...[
          _section('Customer', [
            InfoRow('Name', b.customerName.isNotEmpty ? b.customerName : '—'),
            InfoRow('Email', b.customerEmail.isNotEmpty ? b.customerEmail : '—'),
            InfoRow('Phone', b.customerPhone.isNotEmpty ? PhPhone.display(b.customerPhone) : '—'),
            InfoRow('Account', b.isWalkIn ? 'Walk-in (no app account)' : 'Registered app user'),
          ]),
          const SizedBox(height: AppSpacing.md),
        ],
        _section('Stay', [
          InfoRow('Pet', b.petType.isNotEmpty ? '${b.petLabel} (${b.petType})' : b.petLabel),
          InfoRow('Room', '${b.roomLabel}${b.roomTypeName.isNotEmpty ? ' · ${b.roomTypeName}' : ''}'),
          InfoRow('Check-in', '${Fmt.date(b.checkInDate)} · ${b.checkInTimeSlot.split(' (').first}'),
          InfoRow('Check-out', Fmt.date(b.checkOutDate)),
          InfoRow('Duration', Fmt.nights(b.nightsCount)),
        ]),
        const SizedBox(height: AppSpacing.md),
        _section('Price', [
          if (b.pricePerNight > 0) InfoRow('Room (${Fmt.pesoShort(b.pricePerNight)} × ${b.nightsCount})', Fmt.peso(b.pricePerNight * b.nightsCount)),
          for (final a in b.selectedAddOns) InfoRow(a.lineLabel, Fmt.peso(a.subtotal)),
          const Divider(height: 18),
          InfoRow('Total', Fmt.peso(b.totalAmount), emphasize: true),
        ]),
        const SizedBox(height: AppSpacing.md),
        _section('Payment', [
          Row(children: [
            const Expanded(child: Text('Status', style: AppTextStyles.bodySmall)),
            StatusBadge(status: summary.status, label: summary.status.toUpperCase()),
          ]),
          const SizedBox(height: 6),
          InfoRow('Paid', Fmt.peso(summary.paid), valueColor: AppColors.successText),
          InfoRow('Remaining balance', Fmt.peso(summary.balance), valueColor: summary.balance > 0 ? AppColors.errorText : null),
          if (b.paymentMethod.isNotEmpty) InfoRow('Chosen method', b.paymentMethod),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: summary.progress, minHeight: 8, backgroundColor: AppColors.borderLight, color: AppColors.success),
          ),
          if (summary.payments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final p in summary.payments)
              InfoRow('${Fmt.date(p.paymentDate)} · ${p.paymentMethod}${p.isSimulated ? ' (simulated)' : ''}', Fmt.peso(p.amount)),
          ],
        ]),
        if (footer.isNotEmpty) ...[
          const SizedBox(height: 18),
          for (var i = 0; i < footer.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            footer[i],
          ],
        ],
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 6),
          ...children,
        ]),
      );
}
