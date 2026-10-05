import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/upload_rules.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/customer_model.dart';
import '../../models/payment_model.dart';
import '../../models/pet_model.dart';
import '../../services/booking_service.dart';
import '../../services/customer_service.dart';
import '../../services/payment_service.dart';
import '../../services/pet_service.dart';
import '../customer_screens/pets_list_screen.dart' show PetCard;
import 'booking_management.dart';
import '../../core/constants/app_spacing.dart';

/// A-06 Pet management (ADMIN-007; spec §7.5). The admin cannot edit a customer's
/// pet (Q-13) but reviews the uploaded vaccination file: Validate or Reject. Each pet shows its owner and current stay
/// so the admin can locate a pet's room quickly (SRC-F p.11).
class AdminPetsScreen extends StatefulWidget {
  const AdminPetsScreen({super.key});

  @override
  State<AdminPetsScreen> createState() => _AdminPetsScreenState();
}

class _AdminPetsScreenState extends State<AdminPetsScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  late Stream<List<PetModel>> _pets;
  late Stream<List<CustomerModel>> _customers;
  late Stream<List<BookingModel>> _bookings;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _pets = PetService().streamAll();
    _customers = CustomerService().streamAll();
    _bookings = BookingService().streamAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamStateBuilder<List<PetModel>>(
      stream: _pets,
      onRetry: () => setState(_init),
      loadingMessage: 'Loading pets…',
      errorTitle: 'Unable to load pets',
      builder: (context, pets) => StreamBuilder<List<CustomerModel>>(
        stream: _customers,
        builder: (context, cs) => StreamBuilder<List<BookingModel>>(
          stream: _bookings,
          builder: (context, bs) {
            final owners = {for (final c in cs.data ?? const <CustomerModel>[]) c.cusID: c};
            final staying = {for (final b in (bs.data ?? const <BookingModel>[]).where((b) => b.isCheckedIn)) b.petID: b};
            final q = _search.text.trim().toLowerCase();
            final list = pets.where((p) {
              if (_filter == 'Needs review' && !p.needsVaccinationReview) return false;
              if (_filter == 'Staying now' && !staying.containsKey(p.petID)) return false;
              if (_filter == 'Dogs' && p.petType != 'Dog') return false;
              if (_filter == 'Cats' && p.petType != 'Cat') return false;
              if (q.isNotEmpty && !'${p.petName} ${p.breed} ${owners[p.cusID]?.fullName ?? ''}'.toLowerCase().contains(q)) return false;
              return true;
            }).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Search pet, breed or owner…', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: FilterChipsRow(options: const ['All', 'Needs review', 'Staying now', 'Dogs', 'Cats'], selected: _filter, onSelected: (v) => setState(() => _filter = v)),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.pets_rounded, title: 'No pets found', message: 'Pets registered by customers or at walk-in appear here.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          final stay = staying[p.petID];
                          return Stack(children: [
                            PetCard(
                              pet: p,
                              ownerName: owners[p.cusID]?.fullName ?? 'Unknown owner',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPetDetailsScreen(pet: p, owner: owners[p.cusID]))),
                            ),
                            if (stay != null)
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: TagChip('IN ${stay.roomLabel.toUpperCase()}', color: AppColors.chipGreen, icon: Icons.hotel_rounded),
                              ),
                          ]);
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Pet details organised in sections so nothing is repeated (SRC-F p.10):
/// Pet profile · Owner · Current stay · Booking history with payment status.
class AdminPetDetailsScreen extends StatefulWidget {
  final PetModel pet;
  final CustomerModel? owner;
  const AdminPetDetailsScreen({super.key, required this.pet, this.owner});

  @override
  State<AdminPetDetailsScreen> createState() => _AdminPetDetailsScreenState();
}

class _AdminPetDetailsScreenState extends State<AdminPetDetailsScreen> {
  late final Stream<PetModel?> _petStream = PetService().streamPet(widget.pet.petID);
  bool _reviewing = false;
  late final Stream<List<BookingModel>> _bookings = BookingService().streamAll();
  late final Stream<List<PaymentModel>> _payments = PaymentService().streamAll();

  /// Opens the uploaded file (PDF or image) in the browser / the phone's viewer so the admin can read it.
  Future<void> _openFile(PetModel p) async {
    try {
      final ok = await launchUrl(Uri.parse(p.vaccinationFile), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showError(context, 'The file could not be opened on this device.');
    } catch (_) {
      if (mounted) showError(context, 'The file could not be opened on this device.');
    }
  }

  Future<void> _validate(PetModel p) async {
    setState(() => _reviewing = true);
    try {
      await PetService().reviewVaccination(p, validated: true);
      if (mounted) showSuccess(context, "${p.petName}'s vaccination file was validated.");
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _reject(PetModel p) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject vaccination file'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Tell the customer what is wrong, so they can upload a correct file.'),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: ctrl, maxLines: 3, maxLength: 200, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Reject file')),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      showError(context, 'Please give the reason for rejecting the file.');
      return;
    }
    setState(() => _reviewing = true);
    try {
      await PetService().reviewVaccination(p, validated: false, note: reason);
      if (mounted) showSuccess(context, "${p.petName}'s vaccination file was rejected.");
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PetModel?>(
        stream: _petStream,
        initialData: widget.pet,
        builder: (context, snap) => _page(context, snap.data ?? widget.pet),
      );

  Widget _page(BuildContext context, PetModel p) {
    final o = widget.owner;
    return Scaffold(
      appBar: AppBar(title: Text(p.petName)),
      body: StreamStateBuilder<List<BookingModel>>(
        stream: _bookings,
        builder: (context, all) => StreamBuilder<List<PaymentModel>>(
          stream: _payments,
          builder: (context, ps) {
            final pay = BookingPaymentSummary.groupByBooking(ps.data ?? const []);
            final history = all.where((b) => b.petID == p.petID).toList();
            final current = history.where((b) => b.isCheckedIn).firstOrNull;
            return MaxWidth(
              child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl), children: [
                Center(child: AppImage(url: p.petPhoto, width: 110, height: 110, radius: 55)),
                const SizedBox(height: AppSpacing.md),
                _section('Pet profile', [
                  InfoRow('Name', p.petName),
                  InfoRow('Type / breed', '${p.petType} · ${p.breed}'),
                  InfoRow('Gender', p.gender),
                  InfoRow('Size', p.weightSize),
                  InfoRow('Birthdate', p.birthdate == null ? '—' : Fmt.date(p.birthdate!)),
                  InfoRow('Registered', Fmt.date(p.createdAt)),
                ]),
                const SizedBox(height: AppSpacing.md),
                _section('Vaccination record', [
                  if (p.hasVaccinationRecord) ...[
                    Row(children: [
                      Expanded(child: Text('Review status', style: AppTextStyles.bodyMedium)),
                      StatusBadge(status: p.vaccinationBadgeStatus, label: p.vaccinationBadgeLabel),
                    ]),
                    if (p.vaccinationReviewedAt != null) InfoRow('Reviewed', Fmt.date(p.vaccinationReviewedAt!)),
                    if (p.isVaccinationRejected && p.vaccinationNote.isNotEmpty) InfoRow('Reason', p.vaccinationNote),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Decision D5: the record may be a PDF - show a clear indicator
                  // instead of a broken image preview.
                  if (p.hasVaccinationRecord && UploadRules.isPdfUrl(p.vaccinationFile))
                    TintedCard(
                      tintColor: AppColors.berrySoft,
                      child: Row(children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: AppColors.ink),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text('PDF vaccination record on file', style: AppTextStyles.labelLargeRole)),
                      ]),
                    )
                  else if (p.hasVaccinationRecord)
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(child: InteractiveViewer(child: AppImage(url: p.vaccinationFile, fit: BoxFit.contain, radius: 20))),
                      ),
                      child: AppImage(url: p.vaccinationFile, height: 180, width: double.infinity, fit: BoxFit.contain, fallbackIcon: Icons.description_outlined),
                    )
                  else
                    const Text('No vaccination file on record.', style: AppTextStyles.bodyMedium),
                  if (p.hasVaccinationRecord) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(label: 'Open file to check', icon: Icons.open_in_new_rounded, onPressed: () => _openFile(p)),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(child: SecondaryButton(label: 'Reject', icon: Icons.close_rounded, onPressed: _reviewing || p.isVaccinationRejected ? null : () => _reject(p))),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: PrimaryButton(label: 'Validate', icon: Icons.verified_rounded, isLoading: _reviewing, onPressed: p.isVaccinationValidated ? null : () => _validate(p))),
                    ]),
                  ],
                ]),
                const SizedBox(height: AppSpacing.md),
                _section('Owner', [
                  InfoRow('Name', o?.fullName ?? '—'),
                  InfoRow('Phone', o?.phoneDisplay ?? '—'),
                  InfoRow('Email', o?.email ?? '—'),
                  InfoRow('Address', o?.address ?? '—'),
                  InfoRow('Account', o == null ? '—' : (o.hasAccount ? 'Registered app user' : 'Walk-in (no app account)')),
                ]),
                const SizedBox(height: AppSpacing.md),
                _section('Current stay', [
                  if (current == null)
                    const Text('Not checked in right now.', style: AppTextStyles.bodyMedium)
                  else ...[
                    InfoRow('Room', '${current.roomLabel} · ${current.roomTypeName}'),
                    InfoRow('Stay', Fmt.range(current.checkInDate, current.checkOutDate)),
                  ],
                ]),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader('Booking history (${history.length})'),
                if (history.isEmpty) const AppCard(child: Text('No bookings yet.', style: AppTextStyles.bodyMedium)),
                for (final b in history) ...[
                  AdminBookingCard(booking: b, summary: BookingPaymentSummary(b, pay[b.bookingID] ?? const []), compact: true),
                  const SizedBox(height: 10),
                ],
              ]),
            );
          },
        ),
      ),
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
