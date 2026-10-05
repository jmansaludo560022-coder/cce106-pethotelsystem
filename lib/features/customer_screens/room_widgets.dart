import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/room_model.dart';
import '../../models/room_type_model.dart';
import '../../services/catalog_service.dart';
import '../../core/constants/app_spacing.dart';

/// Loads rooms, room types and active reservations once (streams are created
/// in initState — see REPAIR_NOTES) and rebuilds when any of them change.
class CatalogLoader extends StatefulWidget {
  final Widget Function(BuildContext context, List<RoomModel> rooms, List<RoomTypeModel> types, List<RoomReservation> reservations) builder;
  const CatalogLoader({super.key, required this.builder});

  @override
  State<CatalogLoader> createState() => _CatalogLoaderState();
}

class _CatalogLoaderState extends State<CatalogLoader> {
  final _svc = CatalogService();
  late Stream<List<RoomModel>> _rooms;
  late Stream<List<RoomTypeModel>> _types;
  late Stream<List<RoomReservation>> _res;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _rooms = _svc.streamRooms();
    _types = _svc.streamRoomTypes();
    _res = _svc.streamActiveReservations();
  }

  void _retry() => setState(_init);

  @override
  Widget build(BuildContext context) {
    return StreamStateBuilder<List<RoomTypeModel>>(
      stream: _types,
      onRetry: _retry,
      loadingMessage: 'Loading rooms…',
      errorTitle: 'Unable to load rooms',
      builder: (context, types) => StreamStateBuilder<List<RoomModel>>(
        stream: _rooms,
        onRetry: _retry,
        loadingMessage: 'Loading rooms…',
        errorTitle: 'Unable to load rooms',
        builder: (context, rooms) => StreamStateBuilder<List<RoomReservation>>(
          stream: _res,
          onRetry: _retry,
          loadingMessage: 'Checking availability…',
          errorTitle: 'Unable to check availability',
          builder: (context, res) => widget.builder(context, rooms, types, res),
        ),
      ),
    );
  }
}

/// Color for a room type chip, stable per type name.
Color typeTint(String typeName) {
  final i = typeName.codeUnits.fold<int>(0, (s, c) => s + c) % AppColors.chipPalette.length;
  return AppColors.chipPalette[i];
}

/// Horizontal room card (Figma "Browse Rooms"): photo, room number, type chip,
/// price, capacity and slots left, with View Details / Book Now.
class RoomListCard extends StatelessWidget {
  final RoomAvailability item;
  final VoidCallback onView;
  final VoidCallback? onBook;
  const RoomListCard({super.key, required this.item, required this.onView, this.onBook});

  @override
  Widget build(BuildContext context) {
    final r = item.room;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onView,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppImage(url: r.roomPhoto, width: 92, height: 92, fallbackIcon: Icons.meeting_room_rounded),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Room ${r.roomNum}', style: AppTextStyles.headingSmall, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: 6, runSpacing: 4, children: [
                TagChip(item.typeName, color: typeTint(item.typeName)),
                SlotsBadge(item: item),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.type?.description.isNotEmpty == true ? item.type!.description : 'Matina, Davao City',
                style: AppTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(TextSpan(children: [
                TextSpan(text: Fmt.pesoShort(item.price), style: AppTextStyles.priceSmall),
                const TextSpan(text: ' /night', style: AppTextStyles.caption),
              ])),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(child: SecondaryButton(label: 'View Details', onPressed: onView)),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(label: 'Book Now', onPressed: item.bookable ? onBook : null)),
        ]),
      ]),
    );
  }
}

/// "3 slots left" / "Full" / "Maintenance".
class SlotsBadge extends StatelessWidget {
  final RoomAvailability item;
  const SlotsBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final String text;
    final String tone;
    if (item.room.status.toLowerCase() == 'maintenance') {
      text = 'Maintenance';
      tone = 'maintenance';
    } else if (item.slotsLeft <= 0) {
      text = 'Full';
      tone = 'cancelled';
    } else {
      text = item.slotsLeft == 1 ? '1 slot left' : '${item.slotsLeft} slots left';
      tone = item.slotsLeft == 1 ? 'pending' : 'available';
    }
    return StatusBadge(status: tone, label: text);
  }
}
