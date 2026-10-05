import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/add_on_model.dart';
import '../../services/catalog_service.dart';
import 'booking_wizard.dart';
import 'room_widgets.dart' show typeTint;

/// Spec §9.5: the add-on services the admin created, shown to customers on
/// Home as "Services we offer" with name, description, price and unit.
/// Only active add-ons appear (decision D6).
class ServicesRow extends StatefulWidget {
  /// Optional source for tests; defaults to the live add_ons collection.
  final Stream<List<AddOnModel>> Function()? streamFactory;
  const ServicesRow({super.key, this.streamFactory});

  @override
  State<ServicesRow> createState() => _ServicesRowState();
}

class _ServicesRowState extends State<ServicesRow> {
  late Stream<List<AddOnModel>> _addOns = _newStream();

  Stream<List<AddOnModel>> _newStream() => widget.streamFactory?.call() ?? CatalogService().streamActiveAddOns();

  /// Phase 0.5 fix: retry recreates the stream instead of the row silently
  /// disappearing when loading fails.
  void _retry() => setState(() => _addOns = _newStream());

  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('groom') || n.contains('bath') || n.contains('nail')) return Icons.content_cut_rounded;
    if (n.contains('spa') || n.contains('massage')) return Icons.spa_rounded;
    if (n.contains('train')) return Icons.school_rounded;
    if (n.contains('walk') || n.contains('play')) return Icons.directions_walk_rounded;
    if (n.contains('vet') || n.contains('med') || n.contains('check')) return Icons.medical_services_rounded;
    if (n.contains('taxi') || n.contains('pick') || n.contains('transport')) return Icons.local_taxi_rounded;
    if (n.contains('photo') || n.contains('video') || n.contains('update')) return Icons.photo_camera_rounded;
    if (n.contains('food') || n.contains('meal') || n.contains('treat')) return Icons.restaurant_rounded;
    return Icons.pets_rounded;
  }

  void _details(AddOnModel a) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: typeTint(a.addOnName), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.ink, width: 1.5)),
                child: Icon(iconFor(a.addOnName), color: AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(a.addOnName, style: Theme.of(ctx).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 14),
            if (a.description.isNotEmpty) ...[
              Text(a.description, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
            ],
            InfoRow('Price', Fmt.peso(a.price), emphasize: true),
            InfoRow('Charged', a.unit == AddOnUnits.perDay ? 'Per day of the stay' : 'Once per stay'),
            const SizedBox(height: 6),
            Text('Add this service in the Add-ons step when you book a stay.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Book a stay',
              icon: Icons.event_available_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingWizardScreen()));
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AddOnModel>>(
      stream: _addOns,
      builder: (context, snap) {
        final list = snap.data ?? const <AddOnModel>[];
        // No services offered yet: nothing to show (not an error).
        if (!snap.hasError && snap.hasData && list.isEmpty) return const SizedBox.shrink();
        if (snap.hasError) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader('Services we offer'),
            AppCard(
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.errorText),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Services could not be loaded', style: Theme.of(context).textTheme.labelLarge),
                    Text(friendlyError(snap.error), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                const SizedBox(width: AppSpacing.sm),
                TertiaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _retry),
              ]),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('Services we offer', subtitle: 'Add any of these to your pet\'s stay'),
          SizedBox(
            height: 52,
            child: !snap.hasData
                ? const Center(child: PawLoader())
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final a = list[i];
                      // Rounded pill with a circular icon, like the pet chips.
                      return Material(
                        color: AppColors.surface,
                        shape: const StadiumBorder(side: BorderSide(color: AppColors.line, width: AppBorders.width)),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => _details(a),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(color: typeTint(a.addOnName), shape: BoxShape.circle),
                                child: Icon(iconFor(a.addOnName), size: 20, color: AppColors.ink),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(a.addOnName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
                                Text('${Fmt.pesoShort(a.price)} ${a.unitLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                              ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ]);
      },
    );
  }
}

/// Icon for an add-on service, picked from its name.
IconData addOnIcon(String name) => _ServicesRowState.iconFor(name);
