import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/ph_locations.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/ph_form_fields.dart';
import '../../core/widgets/widgets.dart';
import '../../models/customer_model.dart';
import '../../services/customer_service.dart';
import '../customer_screens/booking_wizard.dart';
import '../../core/constants/app_spacing.dart';

/// A-04 Walk-in booking — step 0: choose the customer (WALK-001, WALK-002).
///
/// The admin first searches existing customer records (registered or earlier
/// walk-ins) by name, email or phone. If none match, a new customer record is
/// created WITHOUT a Firebase Auth account (SRC-F p.3, p.7). The booking itself
/// then uses the shared booking wizard in walk-in mode.
class WalkInBookingScreen extends StatefulWidget {
  const WalkInBookingScreen({super.key});

  @override
  State<WalkInBookingScreen> createState() => _WalkInBookingScreenState();
}

class _WalkInBookingScreenState extends State<WalkInBookingScreen> {
  final _search = TextEditingController();
  late final Stream<List<CustomerModel>> _customers = CustomerService().streamAll();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _continueWith(CustomerModel c) =>
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BookingWizardScreen(walkInCustomer: c)));

  Future<void> _newCustomer() async {
    final created = await Navigator.of(context).push<CustomerModel>(MaterialPageRoute(builder: (_) => const _NewWalkInCustomerScreen()));
    if (created != null && mounted) _continueWith(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walk-in Booking')),
      body: StreamStateBuilder<List<CustomerModel>>(
        stream: _customers,
        loadingMessage: 'Loading customer records…',
        builder: (context, customers) {
          final q = _search.text.trim().toLowerCase();
          final matches = q.isEmpty ? <CustomerModel>[] : customers.where((c) => c.searchText.contains(q)).take(20).toList();
          return MaxWidth(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
              const Text('Who is booking?', style: AppTextStyles.headingMedium),
              const Text('Search first to avoid duplicate records. Walk-in customers do not need an app account.', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Name, email or phone', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 14),
              if (q.isNotEmpty && matches.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text('No matching customer. Create a new walk-in record below.', style: AppTextStyles.bodyMedium)),
              for (final c in matches) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => _continueWith(c),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: AppColors.primaryContainer, child: Text(c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '?')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.fullName, style: AppTextStyles.labelLarge),
                        Text('${c.email} · ${c.phoneDisplay}', style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    TagChip(c.hasAccount ? 'APP USER' : 'WALK-IN', color: c.hasAccount ? AppColors.chipBlue : AppColors.chipLavender),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(label: 'New walk-in customer', icon: Icons.person_add_alt_1_rounded, onPressed: _newCustomer),
            ]),
          );
        },
      ),
    );
  }
}

class _NewWalkInCustomerScreen extends StatefulWidget {
  const _NewWalkInCustomerScreen();

  @override
  State<_NewWalkInCustomerScreen> createState() => _NewWalkInCustomerScreenState();
}

class _NewWalkInCustomerScreenState extends State<_NewWalkInCustomerScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  PhAddress _address = PhAddress.empty;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final c = await CustomerService().createWalkIn(
        firstName: _first.text,
        middleName: _middle.text,
        lastName: _last.text,
        email: _email.text,
        phone: PhPhoneField.e164Of(_phone) ?? '',
        address: _address,
      );
      if (mounted) Navigator.pop(context, c);
    } on DuplicateCustomerException catch (d) {
      if (!mounted) return;
      setState(() => _saving = false);
      final use = await confirmDialog(context,
          title: 'Customer already exists',
          message: '${d.existing.fullName} (${d.existing.email}, ${d.existing.phoneDisplay}) already has this ${d.field}. Use that record?',
          confirmLabel: 'Use existing',
          cancelLabel: 'Edit details');
      if (use && mounted) Navigator.pop(context, d.existing);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(title: const Text('New Walk-in Customer')),
      body: MaxWidth(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
            const TintedCard(
              tintColor: AppColors.infoBg,
              child: Text('No login account is created. The record is kept by the hotel and can be searched later.',
                  style: AppTextStyles.infoBanner),
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _first, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name *'), validator: (v) => Validators.required(v, 'First name')),
            gap,
            TextFormField(controller: _middle, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Middle name (optional)')),
            gap,
            TextFormField(controller: _last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name *'), validator: (v) => Validators.required(v, 'Last name')),
            gap,
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Active email *'), validator: Validators.email),
            gap,
            PhPhoneField(controller: _phone),
            gap,
            const SizedBox(height: 6),
            Text('Address', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            PhAddressFields(initial: _address, onChanged: (a) => _address = a),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'Save and continue', isLoading: _saving, onPressed: _save),
          ]),
        ),
      ),
    );
  }
}
