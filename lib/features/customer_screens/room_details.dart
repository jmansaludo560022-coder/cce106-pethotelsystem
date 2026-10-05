import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../services/catalog_service.dart';
import 'booking_wizard.dart';
import 'room_widgets.dart';
import '../../core/constants/app_spacing.dart';

/// C-05 Room details (ROOM-003, ROOM-004): photo, type, description, price,
/// capacity and available slots for the chosen dates, then "Book this room".
class RoomDetailsScreen extends StatefulWidget {
  final String roomID;
  final DateTimeRange? initialDates;
  const RoomDetailsScreen({super.key, required this.roomID, this.initialDates});

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  late DateTimeRange? _dates = widget.initialDates;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final checkIn = _dates?.start ?? today;
    final checkOut = _dates?.end ?? today.add(const Duration(days: 1));
    return Scaffold(
      appBar: AppBar(title: const Text('Room Details')),
      body: CatalogLoader(builder: (context, rooms, types, res) {
        final matches = rooms.where((r) => r.roomID == widget.roomID).toList();
        if (matches.isEmpty) {
          return const EmptyState(icon: Icons.meeting_room_outlined, title: 'Room not found', message: 'This room is no longer available.');
        }
        final item = RoomAvailability.compute(rooms: matches, types: types, reservations: res, checkIn: checkIn, checkOut: checkOut).first;
        return Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xl), children: [
              AppImage(url: item.room.roomPhoto, height: 210, width: double.infinity, radius: 20, fallbackIcon: Icons.meeting_room_rounded),
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(child: Text('Room ${item.room.roomNum}', style: AppTextStyles.headingLarge)),
                TagChip(item.typeName, color: typeTint(item.typeName)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              const Row(children: [
                Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                SizedBox(width: AppSpacing.xs),
                Text('Matina, Davao City', style: AppTextStyles.caption),
              ]),
              const SizedBox(height: 14),
              if ((item.type?.description ?? '').isNotEmpty) Text(item.type!.description, style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(children: [
                  InfoRow('Price per night', Fmt.peso(item.price), emphasize: true),
                  InfoRow('Maximum pets in room', '${item.capacity}'),
                  InfoRow('Room status', item.room.status.toLowerCase() == 'maintenance' ? 'Under maintenance' : 'Open for booking'),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Availability', style: AppTextStyles.headingSmall),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(_dates == null ? 'Tonight' : Fmt.range(checkIn, checkOut), style: AppTextStyles.labelLarge)),
                    SlotsBadge(item: item),
                  ]),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    icon: Icons.calendar_month_rounded,
                    label: 'Check other dates',
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 365)),
                        initialDateRange: _dates,
                      );
                      if (picked != null) setState(() => _dates = picked);
                    },
                  ),
                ]),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
              child: PrimaryButton(
                label: item.bookable ? 'Book this room' : 'Not available for these dates',
                icon: Icons.event_available_rounded,
                onPressed: item.bookable
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BookingWizardScreen(initialRoomID: item.room.roomID, initialDates: _dates)))
                    : null,
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
