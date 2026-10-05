import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/add_on_model.dart';
import '../../models/booking_model.dart';
import '../../models/customer_model.dart';
import '../../models/pet_model.dart';
import '../../models/room_model.dart';
import '../../models/room_type_model.dart';
import '../../providers/session_provider.dart';
import '../../services/booking_service.dart';
import '../../services/catalog_service.dart';
import '../../services/payment_service.dart';
import '../../services/pet_service.dart';
import 'booking_confirmation.dart';
import 'pet_registration.dart';
import 'room_widgets.dart';
import 'services_row.dart' show addOnIcon;
import '../../core/constants/app_spacing.dart';

/// C-06 Booking wizard (BOOK-001 … BOOK-007; Figma "Customer Booking Workflow"):
///   1. Select Pet → 2. Boarding Details (room, dates, arrival slot)
///   → 3. Add-on Services → 4. Review & Payment → Submitted screen.
///
/// The same wizard is used by the admin for walk-in bookings
/// ([walkInCustomer] set, WALK-003): the booking is created as approved and
/// the admin can record a counter payment immediately.
class BookingWizardScreen extends StatefulWidget {
  final String? initialRoomID;
  final String? initialPetID;
  final DateTimeRange? initialDates;
  final CustomerModel? walkInCustomer;

  const BookingWizardScreen({super.key, this.initialRoomID, this.initialPetID, this.initialDates, this.walkInCustomer});

  /// Why Continue / Confirm is disabled on [step], or null when it is enabled.
  static String? blockedReason(int step, {required bool hasPet, required bool hasDates, String? dateError, required bool hasRoom, required bool roomBookable}) {
    String? petReason() => hasPet ? null : 'Select a pet to continue';
    String? roomReason() {
      if (!hasDates) return 'Choose your stay dates to continue';
      if (dateError != null) return dateError;
      if (!hasRoom) return 'Choose a room to continue';
      if (!roomBookable) return 'This room is not available for these dates';
      return null;
    }

    return switch (step) {
      0 => petReason(),
      1 => roomReason(),
      2 => null,
      _ => petReason() ?? roomReason(),
    };
  }

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  static const _titles = ['Select Pet', 'Boarding Details', 'Add-on Services', 'Review Booking'];
  int _step = 0;
  bool _forward = true;
  String? _petID;
  String? _roomID;
  DateTimeRange? _dates;
  String _slot = kCheckInTimeSlots.first;
  final Map<String, int> _addOnQty = {};
  String _payMethod = PaymentMethods.onSiteCash;
  String _walkInPay = 'later'; // 'later' or an admin method (paid in full now)
  bool _submitting = false;

  late Stream<List<PetModel>> _pets;
  // Decision D6: only active add-ons can be added to a new booking.
  late final Stream<List<AddOnModel>> _addOns = CatalogService().streamActiveAddOns();
  CustomerModel? _customer;

  bool get _walkIn => widget.walkInCustomer != null;

  @override
  void initState() {
    super.initState();
    _petID = widget.initialPetID;
    _roomID = widget.initialRoomID;
    _dates = widget.initialDates;
    _customer = widget.walkInCustomer;
    if (_walkIn) _payMethod = 'Counter';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _customer ??= context.read<SessionProvider>().customer;
    _pets = PetService().streamForCustomer(_customer?.cusID ?? '_none_');
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _forward = false;
        _step--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book a Stay')),
        body: const EmptyState(icon: Icons.person_off_outlined, title: 'Profile not loaded', message: 'Please wait a moment or sign in again.'),
      );
    }
    return PopScope(
      canPop: _step == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_walkIn ? 'Walk-in booking' : 'Book a stay'),
          leading: IconButton(tooltip: 'Back', icon: const BackButtonIcon(), onPressed: _submitting ? null : _back),
        ),
        body: CatalogLoader(builder: (context, rooms, types, res) {
          return StreamStateBuilder<List<PetModel>>(
            stream: _pets,
            loadingMessage: 'Loading pets…',
            errorTitle: 'Unable to load pets',
            builder: (context, pets) => StreamStateBuilder<List<AddOnModel>>(
              stream: _addOns,
              loadingMessage: 'Loading add-ons…',
              builder: (context, addOns) => _body(pets, rooms, types, res, addOns),
            ),
          );
        }),
      ),
    );
  }

  Widget _body(List<PetModel> pets, List<RoomModel> rooms, List<RoomTypeModel> types, List<RoomReservation> res, List<AddOnModel> addOns) {
    final checkIn = _dates?.start;
    final checkOut = _dates?.end;
    final avail = RoomAvailability.compute(
      rooms: rooms,
      types: types,
      reservations: res,
      checkIn: checkIn ?? dateOnly(DateTime.now()),
      checkOut: checkOut ?? dateOnly(DateTime.now()).add(const Duration(days: 1)),
    );
    final pet = pets.where((p) => p.petID == _petID).firstOrNull;
    final room = avail.where((a) => a.room.roomID == _roomID).firstOrNull;
    final nights = (checkIn != null && checkOut != null) ? nightsBetween(checkIn, checkOut) : 0;
    final chosenAddOns = addOns
        .where((a) => (_addOnQty[a.addOnID] ?? 0) > 0)
        .map((a) => SelectedAddOn(
              addOnID: a.addOnID,
              addOnName: a.addOnName,
              price: a.price,
              quantity: _addOnQty[a.addOnID]!,
              unit: a.unit,
              // Per-day services follow the chosen nights (recomputed if the dates change).
              days: AddOnUnits.daysFor(a.unit, nights),
            ))
        .toList();
    final total = (room != null && nights > 0)
        ? calculateBookingTotal(pricePerNight: room.price, nights: nights, addOns: chosenAddOns.map((a) => a.line))
        : 0.0;

    final dateError = _dates == null ? null : validateStayDates(checkIn, checkOut);
    final petBlock = (_step == 0 && pet != null && !_walkIn) ? pet.bookingBlockReason : null;
    final reason = petBlock ?? BookingWizardScreen.blockedReason(
      _step,
      hasPet: pet != null,
      hasDates: _dates != null,
      dateError: dateError,
      hasRoom: room != null,
      roomBookable: room?.bookable ?? false,
    );
    final canContinue = reason == null;

    final content = switch (_step) {
      0 => _stepPet(pets),
      1 => _stepRoom(avail, dateError),
      2 => _stepAddOns(addOns),
      _ => _stepReview(pet!, room!, nights, chosenAddOns, total),
    };

    final reduced = AppMotion.reduced(context);
    return Column(children: [
      MaxWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.lg),
          child: BookingProgressHeader(title: _titles[_step], step: _step, total: _titles.length),
        ),
      ),
      Expanded(
        child: MaxWidth(
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.normal),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            // Shared-axis horizontal between steps; a plain fade with reduced motion.
            transitionBuilder: (child, anim) {
              final fade = FadeTransition(opacity: anim, child: child);
              if (reduced) return fade;
              final incoming = child.key == ValueKey(_step);
              final dx = (incoming == _forward) ? 0.08 : -0.08;
              return SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim), child: fade);
            },
            child: KeyedSubtree(key: ValueKey(_step), child: content),
          ),
        ),
      ),
      Container(
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.ink, width: AppBorders.width))),
        child: SafeArea(
          top: false,
          child: MaxWidth(
            child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (reason != null && !_submitting) ...[
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(reason, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted))),
                ]),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total amount', style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.inkMuted)),
                  FittedBox(fit: BoxFit.scaleDown, child: AnimatedPeso(value: total, style: AppTextStyles.priceMedium)),
                ]),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: _step < 3
                    ? PrimaryButton(
                        label: 'Continue',
                        onPressed: canContinue
                            ? () => setState(() {
                                  _forward = true;
                                  _step++;
                                })
                            : null,
                      )
                    : PrimaryButton(
                        label: _walkIn ? 'Confirm Walk-in' : 'Confirm Booking',
                        isLoading: _submitting,
                        onPressed: canContinue ? () => _submit(pet!, room!, types, chosenAddOns) : null,
                      ),
              ),
            ]),
            ]),
          ),
          ),
        ),
      ),
    ]);
  }

  // ---------------- Step 1: pet ----------------
  Widget _stepPet(List<PetModel> pets) {
    void addPet() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PetFormScreen(cusID: _customer!.cusID, requireVaccination: !_walkIn)));
    final registerCard = AppCard(
      onTap: addPet,
      child: Row(children: [
        const Mascot(pose: MascotPose.head, size: 52),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pets.isEmpty ? 'Register a pet' : 'Register another pet', style: AppTextStyles.titleMedium),
            Text(
              pets.isEmpty
                  ? (_walkIn ? 'Register the walk-in customer\'s pet first. You come back here after saving.' : 'Add your pet first. You come back here after saving.')
                  : 'You come back here after saving.',
              style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted),
            ),
          ]),
        ),
        const Icon(Icons.add_circle_outline_rounded, color: AppColors.ink),
      ]),
    );
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl), children: [
      Text(pets.isEmpty ? 'No pets yet' : 'Which pet is staying?', style: AppTextStyles.titleMedium),
      const SizedBox(height: AppSpacing.md),
      for (final p in pets) ...[
        SelectableCard(
          selected: p.petID == _petID,
          semanticLabel: p.petName,
          onTap: () => setState(() => _petID = p.petID),
          child: Row(children: [
            AppImage(url: p.petPhoto, width: 64, height: 64, radius: AppRadius.small),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.petName, style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
                Text(p.breed.isNotEmpty ? p.breed : p.petType, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted), overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(spacing: AppSpacing.xs + 2, runSpacing: AppSpacing.xs, children: [
                  TagChip(p.petType, color: AppColors.chipYellow),
                  TagChip(p.sizeLabel, color: AppColors.chipBlue),
                  if (!_walkIn && !p.isVaccinationValidated) TagChip(p.vaccinationBadgeLabel, color: AppColors.getStatusBgColor(p.vaccinationBadgeStatus)),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      registerCard,
    ]);
  }

  // ---------------- Step 2: room, dates, slot ----------------
  Widget _stepRoom(List<RoomAvailability> avail, String? dateError) {
    final today = dateOnly(DateTime.now());
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl), children: [
      const Text('Stay dates', style: AppTextStyles.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: today,
            lastDate: today.add(const Duration(days: 365)),
            initialDateRange: _dates,
            helpText: 'Select check-in and check-out',
          );
          if (picked != null) setState(() => _dates = picked);
        },
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _dates == null
                ? const Text('Tap to choose check-in and check-out', style: AppTextStyles.bodyMedium)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Fmt.range(_dates!.start, _dates!.end), style: AppTextStyles.labelLarge),
                    Text(Fmt.nights(nightsBetween(_dates!.start, _dates!.end)), style: AppTextStyles.caption),
                  ]),
          ),
          const Icon(Icons.edit_calendar_outlined, color: AppColors.textMuted),
        ]),
      ),
      if (dateError != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs + 2), child: Text(dateError, style: AppTextStyles.inputError)),
      const SizedBox(height: AppSpacing.xxl),
      Row(children: [
        const Expanded(child: Text('Choose your room', style: AppTextStyles.titleMedium)),
        if (_dates == null) const Text('Pick dates to see slots', style: AppTextStyles.caption),
      ]),
      const SizedBox(height: AppSpacing.sm),
      if (avail.isEmpty)
        const AppCard(child: Text('No rooms are available right now.', style: AppTextStyles.bodyMedium))
      else
        for (final a in avail) ...[
          SelectableCard(
            selected: a.room.roomID == _roomID,
            semanticLabel: 'Room ${a.room.roomNum}',
            // A room under maintenance is unavailable even before dates are picked.
            enabled: a.bookable || (_dates == null && RoomStatus.isBookable(a.room.status)),
            onTap: () => setState(() => _roomID = a.room.roomID),
            child: Row(children: [
              AppImage(url: a.room.roomPhoto, width: 64, height: 64, radius: AppRadius.small, fallbackIcon: Icons.meeting_room_rounded),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Room ${a.room.roomNum} · ${a.typeName}', style: AppTextStyles.labelLarge, overflow: TextOverflow.ellipsis),
                  Text('${Fmt.pesoShort(a.price)}/night · up to ${a.capacity} pet${a.capacity == 1 ? '' : 's'}', style: AppTextStyles.caption),
                ]),
              ),
              if (_dates != null || !RoomStatus.isBookable(a.room.status)) SlotsBadge(item: a),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      const SizedBox(height: AppSpacing.lg),
      const Text('Check-in time slot', style: AppTextStyles.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      RadioGroup<String>(
        groupValue: _slot,
        onChanged: (v) => setState(() => _slot = v ?? _slot),
        child: Column(children: [
          for (final s in kCheckInTimeSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SelectableCard(
                selected: s == _slot,
                onTap: () => setState(() => _slot = s),
                child: Row(children: [Radio<String>(value: s), Expanded(child: Text(s, style: AppTextStyles.bodyMedium))]),
              ),
            ),
        ]),
      ),
    ]);
  }

  // ---------------- Step 3: add-ons ----------------
  Widget _stepAddOns(List<AddOnModel> addOns) {
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl), children: [
      const Text('Optional add-on services', style: AppTextStyles.titleMedium),
      Text('Pamper your pet during the stay. Each service shows whether it is charged per stay or per day.', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
      const SizedBox(height: AppSpacing.md),
      if (addOns.isEmpty)
        const AppCard(child: Text('No add-on services are offered right now. You can continue.', style: AppTextStyles.bodyMedium)),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 480 ? 2 : 1;
        final w = (c.maxWidth - AppSpacing.md * (cols - 1)) / cols;
        return Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
          for (final a in addOns) SizedBox(width: w, child: _addOnCard(a)),
        ]);
      }),
    ]);
  }

  Widget _addOnCard(AddOnModel a) {
    final qty = _addOnQty[a.addOnID] ?? 0;
    final selected = qty > 0;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.fast),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: selected ? AppColors.mustardSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: AppBorders.width),
        boxShadow: selected ? AppShadows.pop : const [],
      ),
      child: Row(children: [
        IconTile(icon: addOnIcon(a.addOnName), color: typeTint(a.addOnName), size: 44),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.addOnName, style: AppTextStyles.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (a.description.isNotEmpty)
              Text(a.description, style: AppTextStyles.bodySmallRole, maxLines: 3, overflow: TextOverflow.ellipsis),
            Text('${Fmt.peso(a.price)} · ${a.unitLabel}', style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.inkMuted)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        _QtyStepper(value: qty, onChanged: (v) => setState(() => _addOnQty[a.addOnID] = v)),
      ]),
    );
  }

  // ---------------- Step 4: review + payment ----------------
  Widget _stepReview(PetModel pet, RoomAvailability room, int nights, List<SelectedAddOn> addOns, double total) {
    final muted = AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted);
    return ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl), children: [
      // Receipt-style summary (spec §9.3).
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.ink, width: AppBorders.width),
          boxShadow: AppShadows.pop,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.ink),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Booking summary', style: AppTextStyles.titleMedium)),
            Text(Fmt.nights(nights), style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.inkMuted)),
          ]),
          const DashedDivider(),
          if (_walkIn) InfoRow('Customer', _customer!.fullName),
          InfoRow('Pet', '${pet.petName} (${pet.breed})'),
          InfoRow('Room', 'Room ${room.room.roomNum} · ${room.typeName}'),
          InfoRow('Check-in', '${Fmt.date(_dates!.start)} · ${_slot.split(' (').first}'),
          InfoRow('Check-out', Fmt.date(_dates!.end)),
          const DashedDivider(),
          InfoRow('Room · ${Fmt.pesoShort(room.price)} × ${Fmt.nights(nights)}', Fmt.peso(room.price * nights)),
          for (final a in addOns) InfoRow(a.lineLabel, Fmt.peso(a.subtotal)),
          if (addOns.isEmpty) Text('No add-on services', style: muted),
          const DashedDivider(),
          Row(children: [
            const Expanded(child: Text('Total', style: AppTextStyles.titleMedium)),
            Text(Fmt.peso(total), style: AppTextStyles.priceMedium),
          ]),
        ]),
      ),
      const SizedBox(height: AppSpacing.xxl),
      const Text('Payment', style: AppTextStyles.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (!_walkIn)
        RadioGroup<String>(
          groupValue: _payMethod,
          onChanged: (v) => setState(() => _payMethod = v ?? _payMethod),
          child: Column(children: [
            _payOption(PaymentMethods.onSiteCash, 'Pay at the front desk', 'Pay in cash when you arrive. Your booking shows as Unpaid until then.', Icons.payments_outlined),
            const SizedBox(height: AppSpacing.sm),
            _payOption(PaymentMethods.eWalletSimulated, 'E-wallet (simulated)', 'Demo only — no real GCash/Maya charge is made. Marked as paid for testing.', Icons.account_balance_wallet_outlined),
          ]),
        )
      else
        DropdownButtonFormField<String>(
          style: AppTextStyles.inputText,
          initialValue: _walkInPay,
          decoration: const InputDecoration(labelText: 'Payment at the counter'),
          items: [
            const DropdownMenuItem(value: 'later', child: Text('Record payment later')),
            for (final m in PaymentMethods.adminMethods) DropdownMenuItem(value: m, child: Text('Paid in full now — $m')),
          ],
          onChanged: (v) => setState(() => _walkInPay = v ?? 'later'),
        ),
      const SizedBox(height: AppSpacing.xxl),
      const Text('Good to know', style: AppTextStyles.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      TintedCard(
        tintColor: AppColors.infoBg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final note in _walkIn
              ? const [
                  'Walk-in bookings are confirmed immediately.',
                  'The customer does not need an app account.',
                ]
              : const [
                  'Your request goes to the hotel for approval.',
                  'Once approved, your digital QR pass unlocks in My Bookings.',
                  'You can cancel a pending or confirmed booking until the day before check-in.',
                ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.infoText)),
                Expanded(child: Text(note, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.infoText))),
              ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _payOption(String value, String title, String subtitle, IconData icon) => SelectableCard(
        selected: _payMethod == value,
        semanticLabel: title,
        onTap: () => setState(() => _payMethod = value),
        child: Row(children: [
          Radio<String>(value: value),
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.labelLarge),
              Text(subtitle, style: AppTextStyles.caption),
            ]),
          ),
        ]),
      );

  Future<void> _submit(PetModel pet, RoomAvailability room, List<RoomTypeModel> types, List<SelectedAddOn> addOns) async {
    setState(() => _submitting = true);
    try {
      final svc = BookingService();
      final method = _walkIn ? (_walkInPay == 'later' ? 'Counter (pending)' : _walkInPay) : _payMethod;
      final id = await svc.createBooking(
        customer: _customer!,
        pet: pet,
        room: room.room,
        roomType: room.type!,
        checkIn: _dates!.start,
        checkOut: _dates!.end,
        timeSlot: _slot,
        addOns: addOns,
        paymentMethod: method,
        walkIn: _walkIn,
      );
      if (_walkIn && _walkInPay != 'later') {
        final booking = await svc.getBooking(id);
        if (booking != null) {
          await PaymentService().recordPayment(booking: booking, amount: booking.totalAmount, method: _walkInPay);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BookingSubmittedScreen(bookingID: id, walkIn: _walkIn)));
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showError(context, friendlyError(e));
      }
    }
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
        onPressed: () => onChanged(1),
        child: const Text('Add'),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.outlined(tooltip: 'Remove one', visualDensity: VisualDensity.compact, onPressed: () => onChanged(value - 1), icon: const Icon(Icons.remove_rounded, size: 18)),
      SizedBox(width: 26, child: Text('$value', textAlign: TextAlign.center, style: AppTextStyles.labelLarge)),
      IconButton.filled(
        tooltip: 'Add one',
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(backgroundColor: AppColors.ink),
        onPressed: value >= 5 ? null : () => onChanged(value + 1),
        icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.onInk),
      ),
    ]);
  }
}
