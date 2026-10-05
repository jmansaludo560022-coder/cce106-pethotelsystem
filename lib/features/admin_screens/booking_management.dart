import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../customer_screens/booking_summary.dart' show BookingDetailsBody;
import 'customer_management.dart';
import 'payments.dart' show PaymentDetailsScreen;

/// A-03 Bookings management (ADMIN-002 … ADMIN-004; spec §7.2).
/// Grouped by status with a room filter (Q-09 recommendation) and search by
/// customer, pet, room or reference. Replaces the old "Approvals" screen,
/// which showed placeholder IDs and had overflowing buttons.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  static const _filters = ['Pending', 'Confirmed', 'Checked in', 'Completed', 'Cancelled', 'All'];
  String _filter = 'Pending';
  String _room = 'All rooms';
  final _search = TextEditingController();
  late Stream<List<BookingModel>> _bookings;
  late Stream<List<PaymentModel>> _payments;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _bookings = BookingService().streamAll();
    _payments = PaymentService().streamAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static bool _matches(BookingModel b, String f) => switch (f) {
        'Pending' => b.isPending,
        'Confirmed' => b.isApproved,
        'Checked in' => b.isCheckedIn,
        'Completed' => b.isCheckedOut,
        'Cancelled' => b.isCancelled || b.isRejected,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'walkin',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalkInBookingScreen())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Walk-in'),
      ),
      body: StreamStateBuilder<List<BookingModel>>(
        stream: _bookings,
        onRetry: () => setState(_init),
        loadingMessage: 'Loading bookings…',
        errorTitle: 'Unable to load bookings',
        builder: (context, all) => StreamBuilder<List<PaymentModel>>(
          stream: _payments,
          builder: (context, ps) {
            final pay = BookingPaymentSummary.groupByBooking(ps.data ?? const []);
            final rooms = {for (final b in all) if (b.roomNum.isNotEmpty) b.roomNum}.toList()..sort();
            final q = _search.text.trim().toLowerCase();
            final list = all.where((b) {
              if (!_matches(b, _filter)) return false;
              if (_room != 'All rooms' && b.roomNum != _room) return false;
              if (q.isNotEmpty &&
                  !'${b.customerName} ${b.customerEmail} ${b.customerPhone} ${b.petName} ${b.roomNum} ${Fmt.ref(b.bookingID)}'.toLowerCase().contains(q)) {
                return false;
              }
              return true;
            }).toList();
            int count(String f) => all.where((b) => _matches(b, f)).length;

            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'Search customer, pet, room, ref…', prefixIcon: Icon(Icons.search_rounded)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      style: AppTextStyles.inputText,
                      initialValue: rooms.contains(_room) ? _room : 'All rooms',
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14)),
                      items: ['All rooms', ...rooms].map((r) => DropdownMenuItem(value: r, child: Text(r == 'All rooms' ? r : 'Room $r', overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _room = v ?? 'All rooms'),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: FilterChipsRow(
                  options: _filters.map((f) => f == 'All' ? 'All (${all.length})' : '$f (${count(f)})').toList(),
                  selected: _filter == 'All' ? 'All (${all.length})' : '$_filter (${count(_filter)})',
                  onSelected: (v) => setState(() => _filter = v.split(' (').first),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(icon: Icons.event_note_outlined, title: 'No ${_filter.toLowerCase()} bookings', message: 'Nothing matches the current filters.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 6, AppSpacing.lg, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (_, i) => AdminBookingCard(booking: list[i], summary: BookingPaymentSummary(list[i], pay[list[i].bookingID] ?? const [])),
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Booking card for admin lists (dashboard + bookings). Shows real names,
/// never raw IDs (fixes ISS-09); Accept (primary) and Reject (red) for pending.
class AdminBookingCard extends StatelessWidget {
  final BookingModel booking;
  final BookingPaymentSummary? summary;
  final bool compact;
  const AdminBookingCard({super.key, required this.booking, this.summary, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminBookingDetailsScreen(bookingID: b.bookingID))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.customerName.isNotEmpty ? b.customerName : 'Customer', style: AppTextStyles.labelLarge, overflow: TextOverflow.ellipsis),
              Text('${b.petLabel} · ${b.roomLabel}${b.roomTypeName.isNotEmpty ? ' (${b.roomTypeName})' : ''}',
                  style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
              Text('${Fmt.range(b.checkInDate, b.checkOutDate)} · ${Fmt.nights(b.nightsCount)}', style: AppTextStyles.caption),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StatusBadge(status: b.status),
            if (b.isWalkIn) const Padding(padding: EdgeInsets.only(top: AppSpacing.xs), child: TagChip('WALK-IN', color: AppColors.chipLavender)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(Fmt.peso(b.totalAmount), style: AppTextStyles.priceSmall),
          if (summary != null && !b.isCancelled && !b.isRejected) StatusBadge(status: summary!.status, label: summary!.status.toUpperCase()),
          Text('Ref ${Fmt.ref(b.bookingID)}', style: AppTextStyles.captionSmall),
        ]),
        if (b.isPending && !compact) ...[
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(child: DestructiveButton(label: 'Reject', onPressed: () => rejectBookingFlow(context, b))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: 'Accept', onPressed: () => approveBookingFlow(context, b))),
          ]),
        ],
      ]),
    );
  }
}

Future<void> approveBookingFlow(BuildContext context, BookingModel b) async {
  final ok = await confirmDialog(
    context,
    title: 'Accept this booking?',
    message: '${b.customerName} · ${b.petLabel} · ${b.roomLabel}\n${Fmt.range(b.checkInDate, b.checkOutDate)}\n\n'
        'The customer\'s QR pass will be unlocked, and the stay will count toward this room\'s capacity.',
    confirmLabel: 'Accept',
  );
  if (!ok || !context.mounted) return;
  try {
    await BookingService().approve(b);
    if (context.mounted) showSuccess(context, 'Booking accepted.');
  } catch (e) {
    if (context.mounted) showError(context, friendlyError(e));
  }
}

Future<void> rejectBookingFlow(BuildContext context, BookingModel b) async {
  final reason = await promptDialog(context, title: 'Reject booking?', hint: 'Reason for the customer (optional)', confirmLabel: 'Reject', destructive: true);
  if (reason == null || !context.mounted) return;
  try {
    await BookingService().reject(b.bookingID, reason: reason);
    if (context.mounted) showSuccess(context, 'Booking rejected.');
  } catch (e) {
    if (context.mounted) showError(context, friendlyError(e));
  }
}

Future<void> adminCancelFlow(BuildContext context, BookingModel b) async {
  final ok = await confirmDialog(context,
      title: 'Cancel this booking?', message: 'The room slot is released. This cannot be undone.', confirmLabel: 'Cancel booking', cancelLabel: 'Keep', destructive: true);
  if (!ok || !context.mounted) return;
  try {
    await BookingService().adminCancel(b.bookingID);
    if (context.mounted) showSuccess(context, 'Booking cancelled.');
  } catch (e) {
    if (context.mounted) showError(context, friendlyError(e));
  }
}

/// Admin booking details with status actions and payment shortcut.
class AdminBookingDetailsScreen extends StatefulWidget {
  final String bookingID;
  const AdminBookingDetailsScreen({super.key, required this.bookingID});

  @override
  State<AdminBookingDetailsScreen> createState() => _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends State<AdminBookingDetailsScreen> {
  late final Stream<BookingModel?> _booking = BookingService().streamBooking(widget.bookingID);
  late final Stream<List<PaymentModel>> _payments = PaymentService().streamAll();

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
            builder: (context, ps) {
              final summary = BookingPaymentSummary(b, (ps.data ?? const []).where((p) => p.bookingID == b.bookingID).toList());
              final actions = <Widget>[
                if (b.isPending) DestructiveButton(label: 'Reject', onPressed: () => rejectBookingFlow(context, b)),
                if (b.isPending) PrimaryButton(label: 'Accept', onPressed: () => approveBookingFlow(context, b)),
                if (b.isApproved) DestructiveButton(label: 'Cancel', onPressed: () => adminCancelFlow(context, b)),
                if (!b.isCancelled && !b.isRejected)
                  InkButton(
                    label: 'Payments',
                    icon: Icons.payments_outlined,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentDetailsScreen(bookingID: b.bookingID))),
                  ),
              ];
              return BookingDetailsBody(booking: b, summary: summary, footer: actions.take(3).toList(), showCustomer: true);
            },
          );
        },
      ),
    );
  }
}
