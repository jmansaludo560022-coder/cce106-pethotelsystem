import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../customer_screens/booking_summary.dart' show BookingDetailsBody;

/// A-08 Payments (PAY-003 … PAY-006; Figma "Payment Management" + web flow).
///
/// The ledger is per booking: total revenue, unpaid balance, All/Paid/Partial/
/// Unpaid filters. Status is always calculated from the payments recorded
/// (the web project's MySQL trigger is replaced by app logic — spec §7.7).
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _filter = 'All';
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

  @override
  Widget build(BuildContext context) {
    return StreamStateBuilder<List<BookingModel>>(
      stream: _bookings,
      onRetry: () => setState(_init),
      loadingMessage: 'Loading payments…',
      errorTitle: 'Unable to load payments',
      builder: (context, bookings) => StreamStateBuilder<List<PaymentModel>>(
        stream: _payments,
        onRetry: () => setState(_init),
        builder: (context, payments) {
          final grouped = BookingPaymentSummary.groupByBooking(payments);
          final ledger = bookings
              .where((b) => !b.isCancelled && !b.isRejected)
              .map((b) => BookingPaymentSummary(b, grouped[b.bookingID] ?? const []))
              .toList();
          final revenue = payments.fold<double>(0, (s, p) => s + p.amount);
          final unpaid = ledger.fold<double>(0, (s, l) => s + l.balance);
          final q = _search.text.trim().toLowerCase();
          final list = ledger.where((l) {
            if (_filter != 'All' && l.status != _filter) return false;
            if (q.isNotEmpty && !'${l.booking.customerName} ${Fmt.ref(l.booking.bookingID)} ${l.booking.roomNum}'.toLowerCase().contains(q)) return false;
            return true;
          }).toList();
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'pay_fab',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordPaymentScreen(ledger: ledger))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record'),
            ),
            body: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96), children: [
              Row(children: [
                Expanded(child: StatTile(label: 'Total revenue', value: Fmt.pesoShort(revenue), icon: Icons.trending_up_rounded, tint: AppColors.chipGreen)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: StatTile(label: 'Unpaid balance', value: Fmt.pesoShort(unpaid), icon: Icons.hourglass_bottom_rounded, tint: AppColors.chipYellow)),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search customer, ref or room…', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Payment ledger', style: AppTextStyles.headingSmall),
                const SizedBox(width: 10),
                Expanded(
                  child: FilterChipsRow(
                    options: const ['All', PaymentStatus.paid, PaymentStatus.partial, PaymentStatus.unpaid],
                    selected: _filter,
                    onSelected: (v) => setState(() => _filter = v),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No entries', message: 'Nothing matches this filter.')),
              for (final l in list) ...[_LedgerCard(summary: l), const SizedBox(height: 10)],
            ]),
          );
        },
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final BookingPaymentSummary summary;
  const _LedgerCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final b = summary.booking;
    final last = summary.payments.isEmpty ? null : summary.payments.first;
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentDetailsScreen(bookingID: b.bookingID))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.customerName.isNotEmpty ? b.customerName : 'Customer', style: AppTextStyles.labelLarge, overflow: TextOverflow.ellipsis)),
          StatusBadge(status: summary.status, label: summary.status.toUpperCase()),
        ]),
        Text('Ref ${Fmt.ref(b.bookingID)} · ${b.roomLabel}', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          const Icon(Icons.credit_card_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(last?.paymentMethod ?? (b.paymentMethod.isNotEmpty ? b.paymentMethod : '—'), style: AppTextStyles.caption, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(Fmt.dateShort(last?.paymentDate ?? b.createdAt), style: AppTextStyles.caption),
          const Spacer(),
          Text(
            summary.status == PaymentStatus.paid ? Fmt.peso(summary.paid) : '${Fmt.pesoShort(summary.paid)} / ${Fmt.pesoShort(b.totalAmount)}',
            style: AppTextStyles.priceSmall.copyWith(color: summary.status == PaymentStatus.paid ? AppColors.successText : AppColors.errorText),
          ),
        ]),
      ]),
    );
  }
}

/// Payment details for one booking: financial summary, payment list (each
/// editable) and "Record payment".
class PaymentDetailsScreen extends StatefulWidget {
  final String bookingID;
  const PaymentDetailsScreen({super.key, required this.bookingID});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  late final Stream<BookingModel?> _booking = BookingService().streamBooking(widget.bookingID);
  late final Stream<List<PaymentModel>> _payments = PaymentService().streamAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: StreamStateBuilder<BookingModel?>(
        stream: _booking,
        builder: (context, b) {
          if (b == null) return const EmptyState(icon: Icons.search_off_rounded, title: 'Booking not found', message: 'It may have been removed.');
          return StreamBuilder<List<PaymentModel>>(
            stream: _payments,
            builder: (context, ps) {
              final mine = (ps.data ?? const <PaymentModel>[]).where((p) => p.bookingID == b.bookingID).toList();
              final s = BookingPaymentSummary(b, mine);
              return Column(children: [
                Expanded(child: BookingDetailsBody(booking: b, summary: s, showCustomer: true)),
                if (mine.isNotEmpty)
                  SizedBox(
                    height: 64,
                    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), children: [
                      for (final p in mine)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.sm, bottom: AppSpacing.sm),
                          child: ActionChip(
                            avatar: const Icon(Icons.edit_outlined, size: 16),
                            label: Text('Edit ${Fmt.dateShort(p.paymentDate)} · ${Fmt.pesoShort(p.amount)}'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => EditPaymentScreen(payment: p, booking: b, bookingPayments: mine),
                            )),
                          ),
                        ),
                    ]),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
                    child: PrimaryButton(
                      label: s.balance > 0 ? 'Record payment (${Fmt.peso(s.balance)} due)' : 'Fully paid',
                      icon: Icons.add_card_rounded,
                      onPressed: s.balance > 0 && !b.isCancelled && !b.isRejected
                          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordPaymentScreen(ledger: [s], preselected: b.bookingID)))
                          : null,
                    ),
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

/// Record Payment (web flow, SRC-F p.15): booking (only those with a balance),
/// date, method, amount. Status is set automatically.
class RecordPaymentScreen extends StatefulWidget {
  final List<BookingPaymentSummary> ledger;
  final String? preselected;
  const RecordPaymentScreen({super.key, required this.ledger, this.preselected});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _form = GlobalKey<FormState>();
  late String? _bookingID = widget.preselected;
  String _method = PaymentMethods.adminMethods.first;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  bool _saving = false;

  List<BookingPaymentSummary> get _open => widget.ledger.where((l) => l.balance > 0).toList();
  BookingPaymentSummary? get _selected => _open.where((l) => l.booking.bookingID == _bookingID).firstOrNull;

  @override
  void initState() {
    super.initState();
    final s = _selected;
    if (s != null) _amount.text = s.balance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PaymentService().recordPayment(
        booking: _selected!.booking,
        amount: double.parse(_amount.text.replaceAll(',', '')),
        method: _method,
        date: _date,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, 'Payment recorded.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: _open.isEmpty
          ? const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Nothing to collect', message: 'All active bookings are fully paid.')
          : MaxWidth(
              child: Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
                  DropdownButtonFormField<String>(
                    style: AppTextStyles.inputText,
                    initialValue: _bookingID,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Booking *', helperText: 'Only bookings with a remaining balance are listed.'),
                    items: _open
                        .map((l) => DropdownMenuItem(
                              value: l.booking.bookingID,
                              child: Text('${l.booking.customerName} · ${l.booking.roomLabel} · ${Fmt.pesoShort(l.balance)} due', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _bookingID = v;
                      final sel = _selected;
                      if (sel != null) _amount.text = sel.balance.toStringAsFixed(2);
                    }),
                    validator: (v) => v == null ? 'Choose a booking.' : null,
                  ),
                  if (s != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    TintedCard(
                      tintColor: AppColors.surfaceVariant,
                      child: Column(children: [
                        InfoRow('Booking total', Fmt.peso(s.booking.totalAmount)),
                        InfoRow('Already paid', Fmt.peso(s.paid)),
                        InfoRow('Remaining balance', Fmt.peso(s.balance), emphasize: true),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _dateField(context),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    style: AppTextStyles.inputText,
                    initialValue: _method,
                    decoration: const InputDecoration(labelText: 'Payment method *'),
                    items: PaymentMethods.adminMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _method = v ?? _method),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount received (₱) *'),
                    validator: (v) => validatePaymentAmount(double.tryParse((v ?? '').replaceAll(',', '')), balance: s?.balance ?? 0),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const TintedCard(
                    tintColor: AppColors.infoBg,
                    child: Text('Status is set automatically: amount = remaining balance → Paid; less → Partial.',
                        style: AppTextStyles.infoBanner),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(label: 'Record Payment', isLoading: _saving, onPressed: _save),
                ]),
              ),
            ),
    );
  }

  Widget _dateField(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final d = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDate: _date);
          if (d != null) setState(() => _date = d);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Payment date *', suffixIcon: Icon(Icons.calendar_today_rounded)),
          child: Text(Fmt.date(_date), style: AppTextStyles.inputText),
        ),
      );
}

/// Edit Payment (SRC-F p.16): date, method, amount; status recalculated.
class EditPaymentScreen extends StatefulWidget {
  final PaymentModel payment;
  final BookingModel booking;
  final List<PaymentModel> bookingPayments;
  const EditPaymentScreen({super.key, required this.payment, required this.booking, required this.bookingPayments});

  @override
  State<EditPaymentScreen> createState() => _EditPaymentScreenState();
}

class _EditPaymentScreenState extends State<EditPaymentScreen> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.payment.amount.toStringAsFixed(2));
  late String _method = widget.payment.paymentMethod;
  late DateTime _date = widget.payment.paymentDate;
  bool _saving = false;

  double get _othersPaid => widget.bookingPayments.where((p) => p.paymentID != widget.payment.paymentID).fold(0, (s, p) => s + p.amount);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PaymentService().updatePayment(
        payment: widget.payment,
        booking: widget.booking,
        bookingPayments: widget.bookingPayments,
        amount: double.parse(_amount.text.replaceAll(',', '')),
        method: _method,
        date: _date,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, 'Payment updated.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = {...PaymentMethods.adminMethods, widget.payment.paymentMethod}.toList();
    final maxAllowed = widget.booking.totalAmount - _othersPaid;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Payment')),
      body: MaxWidth(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
            TintedCard(
              tintColor: AppColors.surfaceVariant,
              child: Column(children: [
                InfoRow('Customer', widget.booking.customerName),
                InfoRow('Booking', 'Ref ${Fmt.ref(widget.booking.bookingID)}'),
                InfoRow('Payment ref', widget.payment.referenceNumber.isEmpty ? '—' : widget.payment.referenceNumber),
                InfoRow('Booking total', Fmt.peso(widget.booking.totalAmount)),
                if (widget.payment.isSimulated) const InfoRow('Note', 'Simulated e-wallet payment'),
              ]),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date);
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Payment date *', suffixIcon: Icon(Icons.calendar_today_rounded)),
                child: Text(Fmt.date(_date), style: AppTextStyles.inputText),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              style: AppTextStyles.inputText,
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment method *'),
              items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount (₱) *', helperText: 'Maximum ${Fmt.peso(maxAllowed)}'),
              validator: (v) => validatePaymentAmount(double.tryParse((v ?? '').replaceAll(',', '')), balance: maxAllowed),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'Save Changes', isLoading: _saving, onPressed: _save),
          ]),
        ),
      ),
    );
  }
}
