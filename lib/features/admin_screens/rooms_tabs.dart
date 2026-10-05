import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/logic/booking_rules.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../models/booking_model.dart';
import '../../models/room_model.dart';
import '../../models/room_type_model.dart';
import '../../services/booking_service.dart';
import '../../services/catalog_service.dart';
import '../customer_screens/room_widgets.dart';
import 'booking_management.dart';
import '../../core/constants/app_spacing.dart';

/// A-05 Rooms & Room Types (ADMIN-005, ADMIN-006; Figma "Room Inventory").
/// One screen with two tabs: Inventory and Types & Pricing; pill buttons,
/// clear borders (SRC-F p.7).
class RoomsManagementScreen extends StatefulWidget {
  const RoomsManagementScreen({super.key});

  @override
  State<RoomsManagementScreen> createState() => _RoomsManagementScreenState();
}

class _RoomsManagementScreenState extends State<RoomsManagementScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'rooms_fab',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _tabs.index == 0 ? const RoomFormScreen() : const RoomTypeFormScreen(),
        )),
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabs.index == 0 ? 'Add Room' : 'Add Room Type'),
      ),
      body: Column(children: [
        TabBar(controller: _tabs, tabs: const [Tab(text: 'Inventory'), Tab(text: 'Types & Pricing')]),
        Expanded(
          child: CatalogLoader(builder: (context, rooms, types, res) {
            final today = dateOnly(DateTime.now());
            final avail = RoomAvailability.compute(rooms: rooms, types: types, reservations: res, checkIn: today, checkOut: today.add(const Duration(days: 1)));
            return TabBarView(controller: _tabs, children: [_inventory(avail), _types(types, rooms)]);
          }),
        ),
      ]),
    );
  }

  Widget _inventory(List<RoomAvailability> avail) {
    if (avail.isEmpty) {
      return const EmptyState(icon: Icons.meeting_room_outlined, title: 'No rooms yet', message: 'Add a room type first, then add rooms to it.');
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 3 : 2);
      const gap = 12.0;
      final w = (c.maxWidth - 32 - gap * (cols - 1)) / cols;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
        child: Wrap(spacing: gap, runSpacing: gap, children: [
          for (final a in avail) SizedBox(width: w, child: _RoomCard(item: a)),
        ]),
      );
    });
  }

  Widget _types(List<RoomTypeModel> types, List<RoomModel> rooms) {
    if (types.isEmpty) {
      return const EmptyState(icon: Icons.category_outlined, title: 'No room types yet', message: 'Create room types (e.g. Standard Room) with their nightly price and capacity.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
      itemCount: types.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) {
        final t = types[i];
        final count = rooms.where((r) => r.roomTypeID == t.roomTypeID).length;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(t.typeName, style: AppTextStyles.headingSmall)),
              Text('${Fmt.pesoShort(t.pricePerNight)}/night', style: AppTextStyles.priceSmall),
            ]),
            Text('Max ${t.maxCapacity} pet${t.maxCapacity == 1 ? '' : 's'} per room · $count room${count == 1 ? '' : 's'}', style: AppTextStyles.caption),
            if (t.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t.description, style: AppTextStyles.bodySmall)),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              IconButton(
                tooltip: 'Delete type',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () async {
                  final ok = await confirmDialog(context, title: 'Delete ${t.typeName}?', message: 'Only room types without rooms can be deleted.', confirmLabel: 'Delete', destructive: true);
                  if (!ok || !mounted) return;
                  try {
                    await CatalogService().deleteRoomType(t);
                    if (mounted) showSuccess(context, 'Room type deleted.');
                  } catch (e) {
                    if (mounted) showError(context, friendlyError(e));
                  }
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: SecondaryButton(label: 'Edit Type', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomTypeFormScreen(existing: t))))),
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton(label: '+ Add Room', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomFormScreen(presetTypeID: t.roomTypeID))))),
            ]),
          ]),
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomAvailability item;
  const _RoomCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final r = item.room;
    final maintenance = r.status.toLowerCase() == 'maintenance';
    final status = maintenance ? 'maintenance' : (item.guestsNow > 0 ? 'checked_in' : 'available');
    final label = maintenance ? 'MAINTENANCE' : (item.guestsNow > 0 ? 'OCCUPIED ${item.guestsNow}/${item.capacity}' : 'AVAILABLE');
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminRoomDetailsScreen(roomID: r.roomID))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppImage(url: r.roomPhoto, height: 96, width: double.infinity, radius: 0, fallbackIcon: Icons.meeting_room_rounded),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Room ${r.roomNum}', style: AppTextStyles.labelLarge, overflow: TextOverflow.ellipsis),
            Text(item.typeName, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: StatusBadge(status: status, label: label)),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: EdgeInsets.zero),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomFormScreen(existing: r))),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: EdgeInsets.zero),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminRoomDetailsScreen(roomID: r.roomID))),
                  child: const Text('View'),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// View Room: information + booking history (SRC-F p.9).
class AdminRoomDetailsScreen extends StatefulWidget {
  final String roomID;
  const AdminRoomDetailsScreen({super.key, required this.roomID});

  @override
  State<AdminRoomDetailsScreen> createState() => _AdminRoomDetailsScreenState();
}

class _AdminRoomDetailsScreenState extends State<AdminRoomDetailsScreen> {
  late final Stream<List<BookingModel>> _bookings = BookingService().streamAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Room Details')),
      body: CatalogLoader(builder: (context, rooms, types, res) {
        final room = rooms.where((r) => r.roomID == widget.roomID).firstOrNull;
        if (room == null) return const EmptyState(icon: Icons.meeting_room_outlined, title: 'Room not found', message: 'It may have been deleted.');
        final today = dateOnly(DateTime.now());
        final a = RoomAvailability.compute(rooms: [room], types: types, reservations: res, checkIn: today, checkOut: today.add(const Duration(days: 1))).first;
        return StreamStateBuilder<List<BookingModel>>(
          stream: _bookings,
          builder: (context, all) {
            final history = all.where((b) => b.roomID == room.roomID).toList();
            return MaxWidth(
              child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl), children: [
                AppImage(url: room.roomPhoto, height: 180, width: double.infinity, radius: 20, fallbackIcon: Icons.meeting_room_rounded),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(children: [
                    InfoRow('Room number', room.roomNum),
                    InfoRow('Room type', a.typeName),
                    InfoRow('Price per night', Fmt.peso(a.price)),
                    InfoRow('Capacity', '${a.capacity} pet${a.capacity == 1 ? '' : 's'}'),
                    InfoRow('Status', room.status),
                    InfoRow('Checked-in now', '${a.guestsNow}'),
                    InfoRow('Slots left tonight', '${a.slotsLeft}'),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DestructiveButton(
                      label: 'Delete',
                      onPressed: () async {
                        final ok = await confirmDialog(context, title: 'Delete room ${room.roomNum}?', message: 'Rooms with active bookings cannot be deleted.', confirmLabel: 'Delete', destructive: true);
                        if (!ok || !context.mounted) return;
                        try {
                          await CatalogService().deleteRoom(room);
                          if (context.mounted) {
                            Navigator.pop(context);
                            showSuccess(context, 'Room deleted.');
                          }
                        } catch (e) {
                          if (context.mounted) showError(context, friendlyError(e));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: PrimaryButton(label: 'Edit Room', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomFormScreen(existing: room))))),
                ]),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader('Booking history (${history.length})'),
                if (history.isEmpty) const AppCard(child: Text('No bookings for this room yet.', style: AppTextStyles.bodyMedium)),
                for (final b in history) ...[AdminBookingCard(booking: b, compact: true), const SizedBox(height: 10)],
              ]),
            );
          },
        );
      }),
    );
  }
}

/// Add / Edit Room (fields from the web reference, SRC-F p.8–9).
class RoomFormScreen extends StatefulWidget {
  final RoomModel? existing;
  final String? presetTypeID;
  const RoomFormScreen({super.key, this.existing, this.presetTypeID});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _num = TextEditingController(text: widget.existing?.roomNum ?? '');
  late String? _typeID = widget.existing?.roomTypeID ?? widget.presetTypeID;
  late String _status = RoomStatus.values.contains(widget.existing?.status) ? widget.existing!.status : RoomStatus.available;
  late final Stream<List<RoomTypeModel>> _types = CatalogService().streamRoomTypes();
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _num.dispose();
    super.dispose();
  }

  /// Shared PhotoSourceSheet (spec §11.2) with compression (spec §11.1).
  Future<void> _pickPhoto() async {
    final hasPhoto = _photoBytes != null || (!_removePhoto && (widget.existing?.roomPhoto ?? '').isNotEmpty);
    final r = await showPhotoSourceSheet(context, title: 'Room photo', allowRemove: hasPhoto);
    if (r == null || !mounted) return;
    setState(() {
      _photo = r.photo?.file;
      _photoBytes = r.photo?.bytes;
      _removePhoto = r.removed;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final room = RoomModel(
        roomID: widget.existing?.roomID ?? '',
        roomTypeID: _typeID!,
        roomNum: _num.text.trim(),
        roomPhoto: _removePhoto ? '' : (widget.existing?.roomPhoto ?? ''),
        status: _status,
      );
      await CatalogService().saveRoom(room, photo: _photo);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, widget.existing == null ? 'Room ${room.roomNum} added.' : 'Room ${room.roomNum} updated.');
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
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Room' : 'Edit Room ${widget.existing!.roomNum}')),
      body: StreamStateBuilder<List<RoomTypeModel>>(
        stream: _types,
        builder: (context, types) {
          if (types.isEmpty) return const EmptyState(icon: Icons.category_outlined, title: 'Add a room type first', message: 'Rooms must belong to a room type.');
          if (_typeID != null && !types.any((t) => t.roomTypeID == _typeID)) _typeID = null;
          return MaxWidth(
            child: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
                GestureDetector(
                  onTap: _saving ? null : _pickPhoto,
                  child: _photoBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(_photoBytes!, height: 170, width: double.infinity, fit: BoxFit.cover))
                      : AppImage(url: _removePhoto ? '' : (widget.existing?.roomPhoto ?? ''), height: 170, width: double.infinity, radius: 20, fallbackIcon: Icons.add_photo_alternate_outlined),
                ),
                TertiaryButton(label: 'Choose room photo (optional)', icon: Icons.add_a_photo_outlined, onPressed: _saving ? null : _pickPhoto),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  style: AppTextStyles.inputText,
                  initialValue: _typeID,
                  decoration: const InputDecoration(labelText: 'Room type *'),
                  items: types.map((t) => DropdownMenuItem(value: t.roomTypeID, child: Text('${t.typeName} (${Fmt.pesoShort(t.pricePerNight)}/night)'))).toList(),
                  onChanged: (v) => setState(() => _typeID = v),
                  validator: (v) => v == null ? 'Choose a room type.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _num,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Room number *', hintText: 'e.g. RC1 or 101'),
                  validator: (v) => Validators.required(v, 'Room number'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  style: AppTextStyles.inputText,
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status', helperText: 'Occupancy is calculated from bookings automatically.'),
                  items: RoomStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 22),
                PrimaryButton(label: widget.existing == null ? 'Create Room' : 'Save Changes', isLoading: _saving, onPressed: _save),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Add / Edit Room Type (SRC-F p.10).
class RoomTypeFormScreen extends StatefulWidget {
  final RoomTypeModel? existing;
  const RoomTypeFormScreen({super.key, this.existing});

  @override
  State<RoomTypeFormScreen> createState() => _RoomTypeFormScreenState();
}

class _RoomTypeFormScreenState extends State<RoomTypeFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.typeName ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _price = TextEditingController(text: widget.existing?.pricePerNight.toStringAsFixed(0) ?? '');
  late final _cap = TextEditingController(text: widget.existing?.maxCapacity.toString() ?? '1');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _cap]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await CatalogService().saveRoomType(RoomTypeModel(
        roomTypeID: widget.existing?.roomTypeID ?? '',
        typeName: _name.text,
        description: _desc.text,
        pricePerNight: double.parse(_price.text.replaceAll(',', '')),
        maxCapacity: int.parse(_cap.text),
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, 'Room type saved.');
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
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Room Type' : 'Edit ${widget.existing!.typeName}')),
      body: MaxWidth(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl), children: [
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Type name *', hintText: 'e.g. Standard Room'), validator: (v) => Validators.required(v, 'Type name')),
            const SizedBox(height: 14),
            TextFormField(controller: _desc, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
            const SizedBox(height: 14),
            TextFormField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price per night (₱) *'), validator: (v) => Validators.positiveNumber(v, 'Price')),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cap,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max pets per room *', helperText: 'A room of this type can host up to this many pets at the same time.'),
              validator: (v) => Validators.positiveInt(v, 'Capacity'),
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: widget.existing == null ? 'Create Room Type' : 'Save Changes', isLoading: _saving, onPressed: _save),
          ]),
        ),
      ),
    );
  }
}
