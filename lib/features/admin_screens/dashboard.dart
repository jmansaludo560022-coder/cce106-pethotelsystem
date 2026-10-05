import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/dashboard_stats.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import 'admin_shell.dart';
import 'booking_management.dart';
import 'customer_management.dart';

/// A-02 Admin dashboard (ADMIN-001; spec §7.1 KPIs). Compact redesign
/// (owner request 2026-10-03): the first screen answers "what needs me now?"
///   1. Needs attention — pending approvals, check-ins and check-outs today
///   2. Operations — active bookings, pets in house, occupied rooms,
///      active customers; quick actions; requests waiting for approval
///   3. Supporting — weekly revenue and recent bookings
/// Every number comes from Firestore through [DashboardStats].
class AdminDashboardScreen extends StatefulWidget {
  final ValueChanged<AdminModule> onNavigate;
  const AdminDashboardScreen({super.key, required this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
  Widget build(BuildContext context) {
    return StreamStateBuilder<List<BookingModel>>(
      stream: _bookings,
      onRetry: () => setState(_init),
      loadingMessage: 'Loading dashboard…',
      errorTitle: 'Unable to load dashboard',
      builder: (context, bookings) => StreamStateBuilder<List<PaymentModel>>(
        stream: _payments,
        onRetry: () => setState(_init),
        builder: (context, payments) => _content(bookings, payments),
      ),
    );
  }

  Widget _content(List<BookingModel> bookings, List<PaymentModel> payments) {
    final s = DashboardStats.from(bookings, payments, DateTime.now());
    final pendingList = bookings.where((b) => b.isPending).toList()..sort((a, b) => a.checkInDate.compareTo(b.checkInDate));
    final recent = bookings.where((b) => !b.isPending).take(5).toList();
    void go(AdminModule m) => widget.onNavigate(m);

    final attention = _NeedsAttention(stats: s, onOpen: go);
    final kpis = _KpiStrip(stats: s);
    final actions = _QuickActions(onNavigate: go);
    final waiting = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Waiting for approval', subtitle: s.pending == 0 ? 'No requests right now' : null, actionLabel: s.pending > 0 ? 'View all' : null, onAction: () => go(AdminModule.bookings)),
      for (final b in pendingList.take(3)) ...[AdminBookingCard(booking: b), const SizedBox(height: AppSpacing.md)],
    ]);
    final revenue = _RevenueCard(stats: s);
    final recentList = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Recent bookings', actionLabel: 'View all', onAction: () => go(AdminModule.bookings)),
      if (recent.isEmpty)
        AppCard(child: Text('No other bookings yet.', style: AppTextStyles.bodyMediumRole))
      else
        for (final b in recent) ...[AdminBookingCard(booking: b, compact: true), const SizedBox(height: AppSpacing.sm)],
    ]);

    return LayoutBuilder(builder: (context, c) {
      const gap = SizedBox(height: AppSpacing.lg);
      final padding = EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl);
      if (c.maxWidth < 900) {
        return ListView(padding: padding, children: [attention, gap, kpis, gap, actions, const SizedBox(height: AppSpacing.xl), waiting, gap, revenue, const SizedBox(height: AppSpacing.xl), recentList]);
      }
      // Wide screens: actions on the left, figures on the right.
      return SingleChildScrollView(
        padding: padding,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [attention, gap, actions, const SizedBox(height: AppSpacing.xl), waiting])),
          const SizedBox(width: AppSpacing.xl),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [kpis, gap, revenue, const SizedBox(height: AppSpacing.xl), recentList])),
        ]),
      );
    });
  }
}

/// Mustard panel at the top: the three things that need the admin today.
class _NeedsAttention extends StatelessWidget {
  final DashboardStats stats;
  final ValueChanged<AdminModule> onOpen;
  const _NeedsAttention({required this.stats, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.hourglass_top_rounded, stats.pending, 'Pending approval', AdminModule.bookings),
      (Icons.login_rounded, stats.checkInsToday, 'Check-ins today', AdminModule.scanner),
      (Icons.logout_rounded, stats.checkOutsToday, 'Check-outs today', AdminModule.scanner),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mustardSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.ink, width: AppBorders.width),
        boxShadow: AppShadows.pop,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Semantics(header: true, child: Text('Needs attention', style: AppTextStyles.titleMedium))),
          if (stats.needsAttention == 0) Text('All caught up', style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.tealText)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _AttentionTile(icon: items[i].$1, count: items[i].$2, label: items[i].$3, onTap: () => onOpen(items[i].$4))),
          ],
        ]),
      ]),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;
  const _AttentionTile({required this.icon, required this.count, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hot = count > 0;
    return Semantics(
      button: true,
      label: '$count $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          side: BorderSide(color: hot ? AppColors.ink : AppColors.line, width: hot ? AppBorders.width : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 16, color: hot ? AppColors.orangeText : AppColors.inkMuted),
                const SizedBox(width: AppSpacing.xs),
                Text('$count', style: AppTextStyles.priceMedium.copyWith(color: hot ? AppColors.ink : AppColors.inkMuted)),
              ]),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.labelSmallRole, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One compact card with four figures side by side (was four tall cards).
class _KpiStrip extends StatelessWidget {
  final DashboardStats stats;
  const _KpiStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('${stats.activeBookings}', 'Active bookings', Icons.event_available_rounded),
      ('${stats.petsInHouse}', 'Pets in house', Icons.pets_rounded),
      ('${stats.occupiedRooms}', 'Rooms occupied', Icons.meeting_room_rounded),
      ('${stats.activeCustomers}', 'Active customers', Icons.people_alt_rounded),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line, width: AppBorders.width),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1, color: AppColors.line),
            Expanded(
              child: Semantics(
                label: '${items[i].$1} ${items[i].$2}',
                excludeSemantics: true,
                child: Column(children: [
                  Icon(items[i].$3, size: 16, color: AppColors.inkMuted),
                  const SizedBox(height: 2),
                  Text(items[i].$1, style: AppTextStyles.priceMedium),
                  Text(items[i].$2, style: AppTextStyles.labelSmallRole, textAlign: TextAlign.center, maxLines: 2),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<AdminModule> onNavigate;
  const _QuickActions({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.person_add_alt_1_rounded, 'Walk-in booking', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalkInBookingScreen()))),
      (Icons.qr_code_scanner_rounded, 'Scan QR pass', () => onNavigate(AdminModule.scanner)),
      (Icons.meeting_room_outlined, 'Rooms', () => onNavigate(AdminModule.rooms)),
    ];
    return Row(children: [
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Material(
            color: i == 0 ? AppColors.mustard : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              side: const BorderSide(color: AppColors.ink, width: AppBorders.width),
            ),
            child: InkWell(
              onTap: actions[i].$3,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(actions[i].$1, size: 20, color: AppColors.ink),
                    const SizedBox(height: 2),
                    Text(actions[i].$2, style: AppTextStyles.labelMediumRole, textAlign: TextAlign.center, maxLines: 2),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _RevenueCard extends StatelessWidget {
  final DashboardStats stats;
  const _RevenueCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final change = stats.changePercent;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Revenue, last 7 days', style: AppTextStyles.titleMedium),
              Text('${Fmt.dateShort(stats.days.first)} – ${Fmt.date(stats.days.last)}', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.peso(stats.week), style: AppTextStyles.priceMedium),
            if (change != null)
              StatusBadge(status: change >= 0 ? 'approved' : 'cancelled', label: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% vs last week'),
          ]),
        ]),
        const SizedBox(height: AppSpacing.md),
        _BarChart(values: stats.perDay, labels: stats.days.map(Fmt.weekday).toList()),
        if (stats.week == 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('No payments recorded in the last 7 days.', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
          ),
      ]),
    );
  }
}

/// Minimal bar chart (no extra package). Today's bar is highlighted.
class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _BarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    return Semantics(
      label: 'Revenue per day: ${[for (var i = 0; i < values.length; i++) '${labels[i]} ${Fmt.pesoShort(values[i])}'].join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 92,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Tooltip(
                    message: Fmt.peso(values[i]),
                    child: Container(
                      height: max == 0 ? 3 : 3 + 60 * (values[i] / max),
                      decoration: BoxDecoration(
                        color: i == values.length - 1 ? AppColors.mustard : AppColors.mustardSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: i == values.length - 1 ? AppColors.ink : AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(labels[i], style: AppTextStyles.labelSmallRole),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
