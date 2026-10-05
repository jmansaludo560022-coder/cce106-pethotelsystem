import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../core/logic/booking_rules.dart';
import '../core/utils/upload_rules.dart';
import '../models/pet_model.dart';
import 'storage_service.dart';

/// Pets (PET-001 … PET-007, ADMIN-007). Pets are owned by customers/{cusID}.
class PetService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('pets');
  final StorageService _storage = StorageService();

  /// PET-001: real-time list of one customer's pets. No orderBy in the query,
  /// so no composite index is needed (a likely cause of ISS-17); sorted here.
  Stream<List<PetModel>> streamForCustomer(String cusID) =>
      _col.where('cusID', isEqualTo: cusID).snapshots().map(_sorted);

  /// Admin only.
  Stream<List<PetModel>> streamAll() => _col.snapshots().map(_sorted);

  Stream<PetModel?> streamPet(String petID) => _col.doc(petID).snapshots().map((d) => d.exists ? PetModel.fromFirestore(d) : null);

  List<PetModel> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(PetModel.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// A new pet ID created once by the form, so a Retry after a failure writes
  /// the same document instead of creating a duplicate pet (spec TC-07).
  String newPetId() => _col.doc().id;

  /// PET-002 / PET-006: uploads any new files first, then writes the pet.
  /// Nothing is written if an upload fails, so no half-saved pet remains.
  ///
  /// Spec §11.1: the photo and vaccination record now upload in parallel,
  /// each with its own timeout (see [StorageService]), and the database write
  /// is also time-limited so the loader can never spin forever.
  /// [newId] is used when creating (pet.petID empty). The vaccination record
  /// may be an image or a PDF (decision D5); it is stored as `vaccination.<ext>`.
  Future<PetModel> savePet(PetModel pet, {UploadData? vaccinationFile, XFile? photo, String? newId}) async {
    final creating = pet.petID.isEmpty;
    final ref = creating ? _col.doc(newId) : _col.doc(pet.petID);
    final folder = 'pets/${pet.cusID}/${ref.id}';

    final uploads = await Future.wait([
      vaccinationFile != null ? _storage.uploadData(vaccinationFile, folder, fileName: 'vaccination') : Future.value(pet.vaccinationFile),
      photo != null ? _storage.uploadImage(photo, folder, fileName: 'photo') : Future.value(pet.petPhoto),
    ]);

    var saved = pet.copyWith(petID: ref.id, vaccinationFile: uploads[0], petPhoto: uploads[1]);
    // A newly uploaded record always waits for the admin again.
    if (vaccinationFile != null) {
      saved = saved.copyWith(vaccinationStatus: VaccinationStatus.pending, vaccinationNote: '', clearReview: true);
    }
    final Future<void> write;
    if (creating) {
      write = ref.set(saved.toMap());
    } else {
      // Update only the editable fields (keep createdAt / cusID untouched).
      final m = saved.toMap()..remove('createdAt')..remove('cusID');
      write = ref.update(m);
    }
    await write.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Saving took too long. Check your internet connection and tap Retry.'),
    );
    return saved;
  }

  /// Admin only (enforced by firestore.rules): validate or reject the uploaded
  /// vaccination record. A rejection needs a reason, which the customer sees.
  Future<void> reviewVaccination(PetModel pet, {required bool validated, String note = ''}) async {
    if (!pet.hasVaccinationRecord) throw Exception('This pet has no vaccination file to review.');
    if (!validated && note.trim().isEmpty) throw Exception('Please give the reason for rejecting the file.');
    await _col.doc(pet.petID).update({
      'vaccinationStatus': validated ? VaccinationStatus.validated : VaccinationStatus.rejected,
      'vaccinationNote': validated ? '' : note.trim(),
      'vaccinationReviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// PET-007 / Q-26: a pet with a pending, approved or checked-in booking
  /// cannot be deleted.
  Future<void> deletePet(PetModel pet) async {
    final bookings = await _db
        .collection('bookings')
        .where('custID', isEqualTo: pet.cusID)
        .where('petID', isEqualTo: pet.petID)
        .get();
    final hasActive = bookings.docs.any((d) => BookingStatus.active.contains(BookingStatus.normalize(d.data()['status'] ?? '')));
    if (hasActive) {
      throw Exception('${pet.petName} has an active booking. Cancel or complete it before deleting this pet.');
    }
    await _col.doc(pet.petID).delete();
  }
}
