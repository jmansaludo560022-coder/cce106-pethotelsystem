import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../core/logic/booking_rules.dart';
import '../models/add_on_model.dart';
import '../models/booking_model.dart';
import '../models/room_model.dart';
import '../models/room_type_model.dart';
import 'storage_service.dart';

/// Rooms, room types, add-ons and room availability.
///
/// The hardcoded "mock" room types / rooms / add-ons were removed (DATA-003,
/// ISS-14, ISS-24): every screen now shows what the admin configured.
class CatalogService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final StorageService _storage = StorageService();

  // ------------------------------------------------------------------
  // Room types (ADMIN-006)
  // ------------------------------------------------------------------
  Stream<List<RoomTypeModel>> streamRoomTypes() => _db.collection('room_types').snapshots().map((s) {
        final list = s.docs.map(RoomTypeModel.fromFirestore).toList();
        list.sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight));
        return list;
      });

  Future<void> saveRoomType(RoomTypeModel t) async {
    final col = _db.collection('room_types');
    final ref = t.roomTypeID.isEmpty ? col.doc() : col.doc(t.roomTypeID);
    final data = RoomTypeModel(
      roomTypeID: ref.id,
      typeName: t.typeName.trim(),
      description: t.description.trim(),
      pricePerNight: t.pricePerNight,
      maxCapacity: t.maxCapacity,
    ).toMap();
    await ref.set(data, SetOptions(merge: true));
  }

  /// Q-26: a room type that still has rooms cannot be deleted.
  Future<void> deleteRoomType(RoomTypeModel t) async {
    final rooms = await _db.collection('rooms').where('roomTypeID', isEqualTo: t.roomTypeID).limit(1).get();
    if (rooms.docs.isNotEmpty) {
      throw Exception('Move or delete the rooms of "${t.typeName}" before deleting this room type.');
    }
    await _db.collection('room_types').doc(t.roomTypeID).delete();
  }

  // ------------------------------------------------------------------
  // Rooms (ADMIN-005)
  // ------------------------------------------------------------------
  Stream<List<RoomModel>> streamRooms() => _db.collection('rooms').snapshots().map((s) {
        final list = s.docs.map(RoomModel.fromFirestore).toList();
        list.sort((a, b) => a.roomNum.compareTo(b.roomNum));
        return list;
      });

  Stream<RoomModel?> streamRoom(String roomID) =>
      _db.collection('rooms').doc(roomID).snapshots().map((d) => d.exists ? RoomModel.fromFirestore(d) : null);

  /// Room numbers must be unique (spec §9.10 ADMIN-005, proposed rule).
  Future<void> saveRoom(RoomModel room, {XFile? photo}) async {
    final col = _db.collection('rooms');
    final dup = await col.where('roomNum', isEqualTo: room.roomNum.trim()).get();
    if (dup.docs.any((d) => d.id != room.roomID)) {
      throw Exception('Room number ${room.roomNum} already exists.');
    }
    final ref = room.roomID.isEmpty ? col.doc() : col.doc(room.roomID);
    var photoUrl = room.roomPhoto;
    if (photo != null) photoUrl = await _storage.uploadImage(photo, 'rooms/${ref.id}', fileName: 'photo');
    await ref.set(room.copyWith(roomID: ref.id, roomNum: room.roomNum.trim(), roomPhoto: photoUrl).toMap(), SetOptions(merge: true));
  }

  /// Q-26: rooms with pending/approved/checked-in stays cannot be deleted.
  Future<void> deleteRoom(RoomModel room) async {
    final res = await _db.collection('room_reservations').where('roomID', isEqualTo: room.roomID).get();
    final active = res.docs.any((d) => BookingStatus.active.contains(BookingStatus.normalize(d.data()['status'] ?? '')));
    if (active) throw Exception('Room ${room.roomNum} has active bookings. Set it to Maintenance instead.');
    await _db.collection('rooms').doc(room.roomID).delete();
  }

  // ------------------------------------------------------------------
  // Add-on services (ADMIN-008)
  // ------------------------------------------------------------------
  Stream<List<AddOnModel>> streamAddOns() => _db.collection('add_ons').snapshots().map((s) {
        final list = s.docs.map(AddOnModel.fromFirestore).toList();
        list.sort((a, b) => a.addOnName.toLowerCase().compareTo(b.addOnName.toLowerCase()));
        return list;
      });

  /// Decision D6: what customers may see and book — active add-ons only.
  Stream<List<AddOnModel>> streamActiveAddOns() => streamAddOns().map(AddOnModel.activeOnly);

  Future<void> saveAddOn(AddOnModel a) async {
    final col = _db.collection('add_ons');
    final ref = a.addOnID.isEmpty ? col.doc() : col.doc(a.addOnID);
    await ref.set({
      'addOnID': ref.id,
      'addOnName': a.addOnName.trim(),
      'price': a.price,
      'description': a.description.trim(),
      'unit': AddOnUnits.normalize(a.unit),
      'isActive': a.isActive,
    }, SetOptions(merge: true));
  }

  /// Q-26: add-ons used by active bookings cannot be deleted. [bookings] is
  /// the admin's current booking list.
  Future<void> deleteAddOn(AddOnModel a, List<BookingModel> bookings) async {
    final inUse = bookings.any((b) => b.isActive && b.selectedAddOns.any((s) => s.addOnID == a.addOnID));
    if (inUse) throw Exception('"${a.addOnName}" is part of an active booking and cannot be deleted yet.');
    await _db.collection('add_ons').doc(a.addOnID).delete();
  }

  // ------------------------------------------------------------------
  // Availability (ROOM-004, BOOK-003, Q-06 capacity-based)
  // ------------------------------------------------------------------

  /// Active (pending / approved / checked-in) room reservations. Contains only
  /// room + dates, so every signed-in user may read it.
  Stream<List<RoomReservation>> streamActiveReservations() => _db
      .collection('room_reservations')
      .where('status', whereIn: BookingStatus.active)
      .snapshots()
      .map((s) => s.docs.map(RoomReservation.fromFirestore).toList());

  Future<List<RoomReservation>> reservationsForRoom(String roomID) async {
    final s = await _db.collection('room_reservations').where('roomID', isEqualTo: roomID).get();
    return s.docs.map(RoomReservation.fromFirestore).toList();
  }
}

/// A room joined with its type and computed availability (used by lists).
class RoomAvailability {
  final RoomModel room;
  final RoomTypeModel? type;
  final int capacity;
  final int slotsLeft;
  final int guestsNow; // checked-in right now
  const RoomAvailability({required this.room, required this.type, required this.capacity, required this.slotsLeft, required this.guestsNow});

  bool get bookable => RoomStatus.isBookable(room.status) && type != null && slotsLeft > 0;
  double get price => type?.pricePerNight ?? 0;
  String get typeName => type?.typeName ?? 'Unassigned type';

  /// Builds availability for every room for the stay [checkIn]–[checkOut].
  static List<RoomAvailability> compute({
    required List<RoomModel> rooms,
    required List<RoomTypeModel> types,
    required List<RoomReservation> reservations,
    required DateTime checkIn,
    required DateTime checkOut,
  }) {
    final byType = {for (final t in types) t.roomTypeID: t};
    final today = dateOnly(DateTime.now());
    return rooms.map((r) {
      final t = byType[r.roomTypeID];
      final cap = t?.maxCapacity ?? 0;
      final stays = reservations.where((x) => x.roomID == r.roomID).map((x) => x.stay).toList();
      final left = RoomStatus.isBookable(r.status) ? remainingSlots(capacity: cap, stays: stays, checkIn: checkIn, checkOut: checkOut) : 0;
      final now = reservations
          .where((x) => x.roomID == r.roomID && x.status == BookingStatus.checkedIn && !dateOnly(x.checkOutDate).isBefore(today))
          .length;
      return RoomAvailability(room: r, type: t, capacity: cap, slotsLeft: left, guestsNow: now);
    }).toList();
  }
}
