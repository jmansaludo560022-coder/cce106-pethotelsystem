import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../services/catalog_service.dart';
import 'booking_wizard.dart';
import 'room_details.dart';
import 'room_widgets.dart';
import '../../core/constants/app_spacing.dart';

/// C-04 Browse Rooms (ROOM-001, ROOM-002, ROOM-004; Figma "Browse Rooms").
///
/// Filters that now really work: search, room type (from Firestore, not
/// hardcoded tiers), nightly price range, stay dates (capacity availability)
/// and "available only". The old "pet size" filter was removed because no
/// room data exists to match it against (it only checked capacity ≥ 2) —
/// see the implementation report.
class BrowseRoomsScreen extends StatefulWidget {
  final String initialQuery;
  const BrowseRoomsScreen({super.key, this.initialQuery = ''});

  @override
  State<BrowseRoomsScreen> createState() => _BrowseRoomsScreenState();
}

class _BrowseRoomsScreenState extends State<BrowseRoomsScreen> {
  late final _search = TextEditingController(text: widget.initialQuery);
  String _type = 'All';
  RangeValues? _price;
  DateTimeRange? _dates;
  bool _availableOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime get _in => _dates?.start ?? dateOnly(DateTime.now());
  DateTime get _out => _dates?.end ?? dateOnly(DateTime.now()).add(const Duration(days: 1));

  bool get _filtersActive => _price != null || _dates != null || _availableOnly;

  Future<void> _openFilters(double minP, double maxP) async {
    var price = _price ?? RangeValues(minP, maxP);
    var dates = _dates;
    var availOnly = _availableOnly;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Filter rooms', style: AppTextStyles.headingMedium)),
                TextButton(
                  onPressed: () => setS(() {
                    price = RangeValues(minP, maxP);
                    dates = null;
                    availOnly = false;
                  }),
                  child: const Text('Reset'),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                const Expanded(child: Text('Nightly rate', style: AppTextStyles.labelLarge)),
                Text('${Fmt.pesoShort(price.start)} – ${Fmt.pesoShort(price.end)}', style: AppTextStyles.labelMedium),
              ]),
              if (maxP > minP)
                RangeSlider(
                  values: price,
                  min: minP,
                  max: maxP,
                  divisions: ((maxP - minP) / 50).clamp(1, 100).round(),
                  activeColor: AppColors.ink,
                  onChanged: (v) => setS(() => price = v),
                )
              else
                const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text('All rooms have the same price.', style: AppTextStyles.caption)),
              const SizedBox(height: AppSpacing.sm),
              const Text('Stay dates', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                icon: Icons.calendar_month_rounded,
                label: dates == null ? 'Select check-in & check-out' : Fmt.range(dates!.start, dates!.end),
                onPressed: () async {
                  final now = dateOnly(DateTime.now());
                  final picked = await showDateRangePicker(
                    context: ctx,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    initialDateRange: dates,
                    helpText: 'Select stay dates',
                  );
                  if (picked != null) setS(() => dates = picked);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show available rooms only', style: AppTextStyles.labelLarge),
                value: availOnly,
                activeThumbColor: AppColors.ink,
                onChanged: (v) => setS(() => availOnly = v),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(label: 'Apply filters', onPressed: () => Navigator.pop(ctx, true)),
            ]),
          ),
        );
      }),
    );
    if (apply == true) {
      setState(() {
        _price = (price.start <= minP && price.end >= maxP) ? null : price;
        _dates = dates;
        _availableOnly = availOnly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Rooms')),
      body: CatalogLoader(builder: (context, rooms, types, res) {
        final all = RoomAvailability.compute(rooms: rooms, types: types, reservations: res, checkIn: _in, checkOut: _out);
        final prices = types.map((t) => t.pricePerNight).toList()..sort();
        final minP = prices.isEmpty ? 0.0 : prices.first;
        final maxP = prices.isEmpty ? 0.0 : prices.last;
        final q = _search.text.trim().toLowerCase();
        final list = all.where((i) {
          if (_type != 'All' && i.typeName != _type) return false;
          if (q.isNotEmpty &&
              !('room ${i.room.roomNum} ${i.typeName} ${i.type?.description ?? ''}'.toLowerCase().contains(q))) {
            return false;
          }
          if (_price != null && (i.price < _price!.start || i.price > _price!.end)) return false;
          if (_availableOnly && !i.bookable) return false;
          return true;
        }).toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.sm),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search rooms…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Badge(
                isLabelVisible: _filtersActive,
                backgroundColor: AppColors.primary,
                child: IconButton.filled(
                  tooltip: 'Filters',
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: AppColors.onInk, minimumSize: const Size(50, 50)),
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _openFilters(minP, maxP),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: FilterChipsRow(options: ['All', ...types.map((t) => t.typeName)], selected: _type, onSelected: (v) => setState(() => _type = v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 10, AppSpacing.xl, AppSpacing.xs),
            child: Row(children: [
              Text('${list.length} result${list.length == 1 ? '' : 's'}', style: AppTextStyles.labelSmall),
              const Spacer(),
              Flexible(
                child: Text(
                  _dates == null ? 'Slots shown for tonight' : 'Slots for ${Fmt.range(_in, _out)}',
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No rooms match',
                    message: 'Try another room type, date range or price.',
                    actionLabel: 'Clear filters',
                    onAction: () => setState(() {
                      _type = 'All';
                      _price = null;
                      _dates = null;
                      _availableOnly = false;
                      _search.clear();
                    }),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 6, AppSpacing.xl, AppSpacing.xxl),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) {
                      final item = list[i];
                      return RoomListCard(
                        item: item,
                        onView: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => RoomDetailsScreen(roomID: item.room.roomID, initialDates: _dates))),
                        onBook: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => BookingWizardScreen(initialRoomID: item.room.roomID, initialDates: _dates))),
                      );
                    },
                  ),
          ),
        ]);
      }),
    );
  }
}
