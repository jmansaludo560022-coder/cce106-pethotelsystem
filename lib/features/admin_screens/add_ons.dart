import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../models/add_on_model.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/catalog_service.dart';
import 'booking_management.dart';
import '../../core/constants/app_spacing.dart';

/// A-07 Add-on services (ADMIN-008; SRC-F p.12–14): list with search, add,
/// view (usage statistics + booking usage) and edit. "Times used" is computed
/// from real bookings.
class AddOnsManagementScreen extends StatefulWidget {
  const AddOnsManagementScreen({super.key});

  @override
  State<AddOnsManagementScreen> createState() => _AddOnsManagementScreenState();
}

class _AddOnsManagementScreenState extends State<AddOnsManagementScreen> {
  final _search = TextEditingController();
  late Stream<List<AddOnModel>> _addOns;
  late Stream<List<BookingModel>> _bookings;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _addOns = CatalogService().streamAddOns();
    _bookings = BookingService().streamAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addon_fab',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddOnFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Add-on'),
      ),
      body: StreamStateBuilder<List<AddOnModel>>(
        stream: _addOns,
        onRetry: () => setState(_init),
        loadingMessage: 'Loading add-ons…',
        errorTitle: 'Unable to load add-ons',
        builder: (context, addOns) => StreamBuilder<List<BookingModel>>(
          stream: _bookings,
          builder: (context, bs) {
            final bookings = bs.data ?? const <BookingModel>[];
            final q = _search.text.trim().toLowerCase();
            final list = addOns.where((a) => q.isEmpty || '${a.addOnName} ${a.price} ${a.addOnID}'.toLowerCase().contains(q)).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Search by name or price…', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.spa_outlined, title: 'No add-on services', message: 'Add services such as grooming, nail trimming or training.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final a = list[i];
                          final used = _usage(a, bookings);
                          return AppCard(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddOnDetailsScreen(addOn: a))),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.chipLavender, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.spa_outlined),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Flexible(child: Text(a.addOnName, style: AppTextStyles.labelLarge, overflow: TextOverflow.ellipsis)),
                                    if (!a.isActive) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      const StatusBadge(status: 'cancelled', label: 'INACTIVE'),
                                    ],
                                  ]),
                                  Text('${Fmt.peso(a.price)} ${a.unitLabel} · used $used time${used == 1 ? '' : 's'}', style: AppTextStyles.caption),
                                ]),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddOnFormScreen(existing: a))),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () async {
                                  final ok = await confirmDialog(
                                    context,
                                    title: 'Delete ${a.addOnName}?',
                                    message: 'Past bookings keep their add-on details. To stop offering it but keep it on file, edit it and turn off "Offered to customers" instead.',
                                    confirmLabel: 'Delete',
                                    destructive: true,
                                  );
                                  if (!ok || !context.mounted) return;
                                  try {
                                    await CatalogService().deleteAddOn(a, bookings);
                                    if (context.mounted) showSuccess(context, 'Add-on deleted.');
                                  } catch (e) {
                                    if (context.mounted) showError(context, friendlyError(e));
                                  }
                                },
                              ),
                            ]),
                          );
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

int _usage(AddOnModel a, List<BookingModel> bookings) => bookings
    .where((b) => !b.isCancelled && !b.isRejected)
    .expand((b) => b.selectedAddOns)
    .where((s) => s.addOnID == a.addOnID)
    .fold(0, (s, x) => s + x.quantity);

class AddOnDetailsScreen extends StatefulWidget {
  final AddOnModel addOn;
  const AddOnDetailsScreen({super.key, required this.addOn});

  @override
  State<AddOnDetailsScreen> createState() => _AddOnDetailsScreenState();
}

class _AddOnDetailsScreenState extends State<AddOnDetailsScreen> {
  late final Stream<List<BookingModel>> _bookings = BookingService().streamAll();

  @override
  Widget build(BuildContext context) {
    final a = widget.addOn;
    return Scaffold(
      appBar: AppBar(title: Text(a.addOnName), actions: [
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AddOnFormScreen(existing: a))),
        ),
      ]),
      body: StreamStateBuilder<List<BookingModel>>(
        stream: _bookings,
        builder: (context, all) {
          final usedIn = all.where((b) => !b.isCancelled && !b.isRejected && b.selectedAddOns.any((s) => s.addOnID == a.addOnID)).toList();
          final qty = _usage(a, all);
          final revenue = usedIn.expand((b) => b.selectedAddOns).where((s) => s.addOnID == a.addOnID).fold<double>(0, (s, x) => s + x.subtotal);
          return MaxWidth(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl), children: [
              AppCard(
                child: Column(children: [
                  InfoRow('Service', a.addOnName),
                  InfoRow('Current price', '${Fmt.peso(a.price)} ${a.unitLabel}'),
                  InfoRow('Status', a.isActive ? 'Offered to customers' : 'Inactive (hidden from customers)'),
                  if (a.description.isNotEmpty) InfoRow('Description', a.description),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 24) / 3;
                return Row(children: [
                  SizedBox(width: w, child: StatTile(label: 'Bookings', value: '${usedIn.length}', icon: Icons.event_note_rounded, tint: AppColors.chipBlue)),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(width: w, child: StatTile(label: 'Quantity', value: '$qty', icon: Icons.format_list_numbered_rounded, tint: AppColors.chipLavender)),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(width: w, child: StatTile(label: 'Revenue', value: Fmt.pesoShort(revenue), icon: Icons.payments_outlined, tint: AppColors.chipGreen)),
                ]);
              }),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Booking usage (${usedIn.length})'),
              if (usedIn.isEmpty) const AppCard(child: Text('Not used in any booking yet.', style: AppTextStyles.bodyMedium)),
              for (final b in usedIn) ...[AdminBookingCard(booking: b, compact: true), const SizedBox(height: 10)],
            ]),
          );
        },
      ),
    );
  }
}

class AddOnFormScreen extends StatefulWidget {
  final AddOnModel? existing;
  const AddOnFormScreen({super.key, this.existing});

  @override
  State<AddOnFormScreen> createState() => _AddOnFormScreenState();
}

class _AddOnFormScreenState extends State<AddOnFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.addOnName ?? '');
  late final _price = TextEditingController(text: widget.existing?.price.toStringAsFixed(0) ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late String _unit = widget.existing?.unit ?? AddOnUnits.perStay;
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await CatalogService().saveAddOn(AddOnModel(
        addOnID: widget.existing?.addOnID ?? '',
        addOnName: _name.text,
        price: double.parse(_price.text.replaceAll(',', '')),
        description: _description.text.trim(),
        unit: _unit,
        isActive: _active,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, 'Add-on saved.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Add-on' : 'Edit Add-on')),
      body: MaxWidth(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Service name', hintText: 'e.g. Grooming'),
              validator: (v) => Validators.required(v, 'Service name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLength: AddOnModel.maxDescriptionLength,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Short description (optional)', hintText: 'e.g. Bath, blow-dry and nail trim'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price (₱)', helperText: 'Changing the price or unit does not affect existing bookings.'),
              validator: (v) => Validators.positiveNumber(v, 'Price'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Charged', style: AppTextStyles.labelMediumRole.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: AddOnUnits.perStay, label: Text('Per stay'), icon: Icon(Icons.hotel_rounded)),
                ButtonSegment(value: AddOnUnits.perDay, label: Text('Per day'), icon: Icon(Icons.today_rounded)),
              ],
              selected: {_unit},
              onSelectionChanged: (v) => setState(() => _unit = v.first),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _unit == AddOnUnits.perDay ? 'Price × quantity × number of nights.' : 'Price × quantity, once for the whole stay.',
              style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Offered to customers'),
              subtitle: Text(_active
                  ? 'Shown on Home and in the booking flow.'
                  : 'Hidden from customers and new bookings. Existing bookings are not changed.'),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: widget.existing == null ? 'Create add-on' : 'Save changes', isLoading: _saving, onPressed: _save),
          ]),
        ),
      ),
    );
  }
}
